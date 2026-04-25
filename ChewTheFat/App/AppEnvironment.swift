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
    let trends: TrendsRepository
    let goalEvaluator: SessionGoalEvaluator

    let foodSearch: FoodSearchRAG
    let knowledge: KnowledgeGraph
    let modelClient: ModelClientProtocol
    let modelBootstrapper: ModelBootstrapperProtocol
    let toolRegistry: ToolCallDispatcher
    let ticker: ModelChangeTicker
    let preferences: AppPreferences
    let notificationScheduler: NotificationScheduler

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
        let trends = TrendsRepository(context: ctx)
        let invalidateTrends: @MainActor () -> Void = { try? trends.markStale() }
        let foodLog = FoodLogRepository(context: ctx, onChange: invalidateTrends)
        let foodCatalog = FoodCatalogRepository(context: ctx)
        let weightLog = WeightLogRepository(context: ctx, onChange: invalidateTrends)
        self.profile = profile
        self.goals = goals
        self.sessions = SessionRepository(context: ctx)
        self.foodLog = foodLog
        self.foodCatalog = foodCatalog
        self.weightLog = weightLog
        self.memory = MemoryRepository(context: ctx)
        self.trends = trends
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
        registry.register(LogWeightTool(weightLog: weightLog, goals: goals))
        registry.register(SetGoalsTool(goals: goals))
        registry.register(SetProfileInfoTool(profile: profile))
        self.toolRegistry = registry
        self.notificationScheduler = NotificationScheduler()
    }

    /// Creates a new session and, for `.logWeight`, seeds it with a
    /// system-authored "Time to weigh in" turn + a weigh-in picker widget.
    /// UI calls this rather than `sessions.create(goal:)` directly so the
    /// seed logic lives in one place.
    func createSession(goal: SessionGoal) throws -> Session {
        let session = try sessions.create(goal: goal)
        if goal == .logWeight {
            try seedWeighInPrompt(on: session)
        }
        return session
    }

    /// Evaluates `SessionTrigger` against the current data store and creates
    /// a session pre-seeded with the right opening turn and quick-reply
    /// suggestions. Returns `nil` when the trigger says `.general` — the
    /// caller should leave the user on the dashboard rather than auto-route.
    func createTriggeredSession(now: Date = .now) throws -> Session? {
        let trigger = evaluateTrigger(now: now)
        guard trigger.shouldAutoStart else { return nil }
        let session = try sessions.create(goal: trigger.recommendedGoal)
        switch trigger.recommendedGoal {
        case .logWeight:
            try seedWeighInPrompt(on: session)
        case .logMeal:
            if let meal = trigger.mealType, let prompt = trigger.promptText {
                try seedMealPrompt(
                    on: session,
                    mealType: meal,
                    promptText: prompt,
                    suggestions: trigger.suggestions
                )
            }
        default:
            break
        }
        preferences.lastTriggeredSlot = trigger.slotId
        return session
    }

    /// Reads the live state required by `SessionTrigger` and runs the pure
    /// evaluator. Public so the UI can ask "would the trigger fire?" without
    /// committing to a session create (e.g. the auto-trigger gate that
    /// suppresses double-fires within the same slot).
    func evaluateTrigger(now: Date = .now) -> SessionTrigger {
        let lastWeight = (try? weightLog.latest())?.date
        let todaysMeals = (try? foodLog.loggedFoods(on: now)) ?? []
        let mealsSet = Set(todaysMeals.compactMap { MealType(rawValue: $0.meal) })
        let history: (MealType) -> [String] = { [foodLog] meal in
            (try? foodLog.recentMealSummaries(type: meal, limit: 3, now: now)) ?? []
        }
        return SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: lastWeight,
            loggedMealsToday: mealsSet,
            recentMealSummaries: history
        ))
    }

    private func seedMealPrompt(
        on session: Session,
        mealType: MealType,
        promptText: String,
        suggestions: [String]
    ) throws {
        let suggestionsData: Data?
        if suggestions.isEmpty {
            suggestionsData = nil
        } else {
            suggestionsData = try JSONEncoder().encode(suggestions)
        }
        let message = Message(
            author: "assistant",
            textContent: promptText,
            suggestionsJSON: suggestionsData
        )
        try sessions.appendMessage(message, to: session)
    }

    private func seedWeighInPrompt(on session: Session) throws {
        let lastEntry = try? weightLog.latest()
        let currentProfile = try? profile.current()
        let units = PreferredUnitSystem(storedValue: currentProfile?.preferredUnits)
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: lastEntry?.weightKg,
            units: units
        )
        let payload = WeightLogPromptPayload(
            suggestionsKg: suggestions,
            lastEntryKg: lastEntry?.weightKg,
            preferredUnits: units.rawValue
        )
        let widget = WidgetIntent.weightLogPrompt(payload)
        let message = Message(
            author: "assistant",
            textContent: "Time to weigh in. Where are you today?"
        )
        try sessions.appendMessage(message, to: session)
        let encoded = try JSONEncoder().encode(payload)
        let widgetRow = MessageWidget(
            order: 0,
            type: widget.type,
            payload: encoded,
            message: message
        )
        container.mainContext.insert(widgetRow)
        try container.mainContext.save()
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
                TrendsContextSource(trends: trends),
                KnowledgeContextSource(graph: knowledge),
            ],
            assembler: assembler
        )
        let turn = TurnHandler(model: modelClient, dispatcher: toolRegistry)
        let resolver = WidgetIntentResolver(foodLog: foodLog, weightLog: weightLog)
        let writer = MemoryWriter(memory: memory)
        return Orchestrator(
            state: state,
            context: contextManager,
            turn: turn,
            resolver: resolver,
            toolSchemas: toolRegistry.schemas,
            memoryWriter: writer
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

    /// Foreground hook (called on `scenePhase == .active`). Cheap enough to
    /// run on the main actor — windows are at most 7 days of rows and we only
    /// touch the store when `Trends.isStale` is true.
    func recomputeTrendsIfStale(now: Date = .now) {
        let generator = TrendsGenerator(trends: trends, weightLog: weightLog, foodLog: foodLog)
        try? generator.recomputeIfStale(now: now)
    }

    /// Foreground fallback for the daily summary BGTask. If `lastDailySummaryDay`
    /// doesn't match yesterday, run the heuristic generator and stamp the marker.
    func runDailySummaryIfNeeded(now: Date = .now) {
        let generator = DailySummaryGenerator(
            memory: memory,
            foodLog: foodLog,
            weightLog: weightLog,
            preferences: preferences
        )
        generator.runIfNeeded(now: now)
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
    /// `SessionTrigger.slotId` of the most recent auto-triggered session.
    /// Used to suppress repeat fires within the same window — once a slot
    /// has fired, the auto-trigger waits for the next slot or the next day.
    var lastTriggeredSlot: String? {
        didSet { store.lastTriggeredSlot = lastTriggeredSlot }
    }
    /// Per-slot notification toggles surfaced in Settings. All default off
    /// until the user opts in (which also requests UN authorization).
    var weighInNotificationsEnabled: Bool {
        didSet { store.weighInNotificationsEnabled = weighInNotificationsEnabled }
    }
    var breakfastNotificationsEnabled: Bool {
        didSet { store.breakfastNotificationsEnabled = breakfastNotificationsEnabled }
    }
    var lunchNotificationsEnabled: Bool {
        didSet { store.lunchNotificationsEnabled = lunchNotificationsEnabled }
    }
    var dinnerNotificationsEnabled: Bool {
        didSet { store.dinnerNotificationsEnabled = dinnerNotificationsEnabled }
    }
    /// `yyyy-MM-dd` of the last day a daily-summary memory was written.
    /// `DailySummaryGenerator` reads this on foreground to decide whether to
    /// run a fallback recompute (if BGTask never fired).
    var lastDailySummaryDay: String? {
        didSet { store.lastDailySummaryDay = lastDailySummaryDay }
    }

    init(store: PreferenceStore = UserDefaultsPreferenceStore()) {
        self.store = store
        self.webSearchFallbackEnabled = store.webSearchFallbackEnabled
        self.lastTriggeredSlot = store.lastTriggeredSlot
        self.weighInNotificationsEnabled = store.weighInNotificationsEnabled
        self.breakfastNotificationsEnabled = store.breakfastNotificationsEnabled
        self.lunchNotificationsEnabled = store.lunchNotificationsEnabled
        self.dinnerNotificationsEnabled = store.dinnerNotificationsEnabled
        self.lastDailySummaryDay = store.lastDailySummaryDay
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
    var lastTriggeredSlot: String? { get set }
    var weighInNotificationsEnabled: Bool { get set }
    var breakfastNotificationsEnabled: Bool { get set }
    var lunchNotificationsEnabled: Bool { get set }
    var dinnerNotificationsEnabled: Bool { get set }
    var lastDailySummaryDay: String? { get set }
}

nonisolated final class UserDefaultsPreferenceStore: PreferenceStore, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var webSearchFallbackEnabled: Bool {
        get { defaults.bool(forKey: "webSearchFallbackEnabled") }
        set { defaults.set(newValue, forKey: "webSearchFallbackEnabled") }
    }
    var lastTriggeredSlot: String? {
        get { defaults.string(forKey: "lastTriggeredSlot") }
        set { defaults.set(newValue, forKey: "lastTriggeredSlot") }
    }
    var weighInNotificationsEnabled: Bool {
        get { defaults.bool(forKey: "weighInNotificationsEnabled") }
        set { defaults.set(newValue, forKey: "weighInNotificationsEnabled") }
    }
    var breakfastNotificationsEnabled: Bool {
        get { defaults.bool(forKey: "breakfastNotificationsEnabled") }
        set { defaults.set(newValue, forKey: "breakfastNotificationsEnabled") }
    }
    var lunchNotificationsEnabled: Bool {
        get { defaults.bool(forKey: "lunchNotificationsEnabled") }
        set { defaults.set(newValue, forKey: "lunchNotificationsEnabled") }
    }
    var dinnerNotificationsEnabled: Bool {
        get { defaults.bool(forKey: "dinnerNotificationsEnabled") }
        set { defaults.set(newValue, forKey: "dinnerNotificationsEnabled") }
    }
    var lastDailySummaryDay: String? {
        get { defaults.string(forKey: "lastDailySummaryDay") }
        set { defaults.set(newValue, forKey: "lastDailySummaryDay") }
    }
}

nonisolated final class InMemoryPreferenceStore: PreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _enabled: Bool
    private var _lastTriggeredSlot: String?
    private var _weighIn: Bool = false
    private var _breakfast: Bool = false
    private var _lunch: Bool = false
    private var _dinner: Bool = false
    private var _lastSummaryDay: String?

    init(webSearchFallbackEnabled: Bool = false) {
        self._enabled = webSearchFallbackEnabled
    }

    var webSearchFallbackEnabled: Bool {
        get { lock.withLock { _enabled } }
        set { lock.withLock { _enabled = newValue } }
    }
    var lastTriggeredSlot: String? {
        get { lock.withLock { _lastTriggeredSlot } }
        set { lock.withLock { _lastTriggeredSlot = newValue } }
    }
    var weighInNotificationsEnabled: Bool {
        get { lock.withLock { _weighIn } }
        set { lock.withLock { _weighIn = newValue } }
    }
    var breakfastNotificationsEnabled: Bool {
        get { lock.withLock { _breakfast } }
        set { lock.withLock { _breakfast = newValue } }
    }
    var lunchNotificationsEnabled: Bool {
        get { lock.withLock { _lunch } }
        set { lock.withLock { _lunch = newValue } }
    }
    var dinnerNotificationsEnabled: Bool {
        get { lock.withLock { _dinner } }
        set { lock.withLock { _dinner = newValue } }
    }
    var lastDailySummaryDay: String? {
        get { lock.withLock { _lastSummaryDay } }
        set { lock.withLock { _lastSummaryDay = newValue } }
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
