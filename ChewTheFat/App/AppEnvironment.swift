import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let container: ModelContainer
    let contextFactory: ModelContextFactory

    let profile: ProfileRepository
    let goals: GoalRepository
    let sessions: SessionRepository
    let foodLog: FoodLogRepository
    let foodCatalog: FoodCatalogRepository
    let weightLog: WeightLogRepository
    let memory: MemoryRepository
    let goalEvaluator: SessionGoalEvaluator

    let foodSearch: FoodSearchRAG
    let knowledge: KnowledgeGraph
    let modelClient: ModelClientProtocol
    let modelBootstrapper: ModelBootstrapperProtocol
    let toolRegistry: ToolCallDispatcher
    let ticker: ModelChangeTicker
    let preferences: AppPreferences

    init(
        container: ModelContainer,
        preferences: AppPreferences,
        usdaDB: USDAFoodDB? = nil,
        offsDB: OpenFoodFactsDB? = nil,
        modelClient: ModelClientProtocol = StubModelClient(),
        modelBootstrapper: ModelBootstrapperProtocol = NullModelBootstrapper()
    ) {
        self.container = container
        self.contextFactory = ModelContextFactory(container: container)
        self.preferences = preferences
        self.modelClient = modelClient
        self.modelBootstrapper = modelBootstrapper
        self.ticker = ModelChangeTicker()

        let ctx = container.mainContext
        let profile = ProfileRepository(context: ctx)
        let goals = GoalRepository(context: ctx)
        let foodLog = FoodLogRepository(context: ctx)
        let foodCatalog = FoodCatalogRepository(context: ctx)
        let weightLog = WeightLogRepository(context: ctx)
        self.profile = profile
        self.goals = goals
        self.sessions = SessionRepository(context: ctx)
        self.foodLog = foodLog
        self.foodCatalog = foodCatalog
        self.weightLog = weightLog
        self.memory = MemoryRepository(context: ctx)
        self.goalEvaluator = SessionGoalEvaluatorLive(profile: profile, goals: goals)

        let foodSearch = FoodSearchRAG(
            history: UserHistorySource(context: ctx),
            usda: USDAFoodSource(db: usdaDB),
            openFoodFacts: OpenFoodFactsSource(db: offsDB),
            web: WebSearchFallback(),
            webFallbackEnabled: preferences.sendableFallbackReader
        )
        self.foodSearch = foodSearch
        self.knowledge = KnowledgeGraph()

        let registry = ToolCallDispatcher()
        registry.register(FoodSearchTool(rag: foodSearch))
        registry.register(LookupKnowledgeTool(graph: self.knowledge))
        registry.register(LogFoodTool(foodLog: foodLog, foodCatalog: foodCatalog, context: ctx))
        registry.register(LogWeightTool(weightLog: weightLog))
        registry.register(SetGoalsTool(goals: goals))
        registry.register(SetProfileInfoTool(profile: profile))
        self.toolRegistry = registry
    }

    func makeOrchestrator(for session: Session) -> Orchestrator {
        let state = SessionStateManager(
            session: session,
            evaluator: goalEvaluator,
            sessions: sessions
        )
        let client = modelClient
        let assembler = ContextAssembler(
            tokenCounter: { text in await client.countTokens(text) }
        )
        let contextManager = ContextManager(
            sources: [
                ProfileContextSource(profile: profile),
                GoalContextSource(goals: goals),
                GoalProgressContextSource(evaluator: goalEvaluator),
                SessionContextSource(sessions: sessions),
                MemoryContextSource(memory: memory),
                KnowledgeContextSource(graph: knowledge),
            ],
            assembler: assembler
        )
        let turn = TurnHandler(model: modelClient, dispatcher: toolRegistry)
        let resolver = WidgetIntentResolver(foodLog: foodLog, weightLog: weightLog)
        return Orchestrator(
            state: state,
            context: contextManager,
            turn: turn,
            resolver: resolver,
            toolSchemas: toolRegistry.schemas
        )
    }

    static func live() throws -> AppEnvironment {
        let container = try ModelContainerProvider.live()
        let usdaDB = tryOpen { try USDAFoodDB(url: $0) }(
            ReferenceDatabaseLocation.url(forResourceNamed: "usda")
        )
        let offsDB = tryOpen { try OpenFoodFactsDB(url: $0) }(
            ReferenceDatabaseLocation.url(forResourceNamed: "offs")
        )

        let (bootstrapper, modelClient): (ModelBootstrapperProtocol, ModelClientProtocol) = {
            do {
                let b = try ModelBootstrapper()
                let c = try MLXModelClient()
                return (b, c)
            } catch {
                return (NullModelBootstrapper(), StubModelClient())
            }
        }()

        return AppEnvironment(
            container: container,
            preferences: AppPreferences(),
            usdaDB: usdaDB,
            offsDB: offsDB,
            modelClient: modelClient,
            modelBootstrapper: bootstrapper
        )
    }

    /// Best-effort eager warm-up. If the bootstrapper already has weights on
    /// disk, load the container into memory so the first chat turn doesn't pay
    /// cold-start latency. Errors are swallowed — the chat surface retries on
    /// first real request.
    func warmUpModelIfReady() async {
        guard await modelBootstrapper.isReady else { return }
        try? await modelClient.warmUp()
    }

    static func preview() throws -> AppEnvironment {
        try AppEnvironment(
            container: ModelContainerProvider.inMemory(),
            preferences: AppPreferences(store: InMemoryPreferenceStore())
        )
    }

    static func testing() throws -> AppEnvironment {
        try AppEnvironment(
            container: ModelContainerProvider.inMemory(),
            preferences: AppPreferences(store: InMemoryPreferenceStore())
        )
    }
}

/// User-adjustable preferences. Backed by a thread-safe store so the
/// `FoodSearchRAG`'s `@Sendable` webFallbackEnabled closure can read it from
/// any actor, while the UI binds to the @Observable wrapper for live updates.
@MainActor
@Observable
final class AppPreferences {
    @ObservationIgnored private let store: PreferenceStore
    var webSearchFallbackEnabled: Bool {
        didSet { store.webSearchFallbackEnabled = webSearchFallbackEnabled }
    }

    init(store: PreferenceStore = UserDefaultsPreferenceStore()) {
        self.store = store
        self.webSearchFallbackEnabled = store.webSearchFallbackEnabled
    }

    /// Closure consumed by the `@Sendable` webFallbackEnabled hook on
    /// `FoodSearchRAG`. Reads from the thread-safe store, not the @Observable
    /// property (which is @MainActor).
    nonisolated var sendableFallbackReader: @Sendable () -> Bool {
        let store = self.store
        return { store.webSearchFallbackEnabled }
    }
}

/// Thread-safe boolean store for the sendable closures that consume preferences.
nonisolated protocol PreferenceStore: AnyObject, Sendable {
    var webSearchFallbackEnabled: Bool { get set }
}

nonisolated final class UserDefaultsPreferenceStore: PreferenceStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "webSearchFallbackEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var webSearchFallbackEnabled: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

nonisolated final class InMemoryPreferenceStore: PreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _enabled: Bool

    init(webSearchFallbackEnabled: Bool = false) {
        self._enabled = webSearchFallbackEnabled
    }

    var webSearchFallbackEnabled: Bool {
        get { lock.withLock { _enabled } }
        set { lock.withLock { _enabled = newValue } }
    }
}

private func tryOpen<DB>(
    _ open: @escaping (URL) throws -> DB
) -> (URL?) -> DB? {
    { url in
        guard let url else { return nil }
        return try? open(url)
    }
}
