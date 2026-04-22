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
    private let preferences: AppPreferences

    init(
        container: ModelContainer,
        preferences: AppPreferences = .default,
        usdaDB: USDAFoodDB? = nil,
        offsDB: OpenFoodFactsDB? = nil
    ) {
        self.container = container
        self.contextFactory = ModelContextFactory(container: container)
        self.preferences = preferences

        let ctx = container.mainContext
        let profile = ProfileRepository(context: ctx)
        let goals = GoalRepository(context: ctx)
        self.profile = profile
        self.goals = goals
        self.sessions = SessionRepository(context: ctx)
        self.foodLog = FoodLogRepository(context: ctx)
        self.foodCatalog = FoodCatalogRepository(context: ctx)
        self.weightLog = WeightLogRepository(context: ctx)
        self.memory = MemoryRepository(context: ctx)
        self.goalEvaluator = SessionGoalEvaluatorLive(profile: profile, goals: goals)

        self.foodSearch = FoodSearchRAG(
            history: UserHistorySource(context: ctx),
            usda: USDAFoodSource(db: usdaDB),
            openFoodFacts: OpenFoodFactsSource(db: offsDB),
            web: WebSearchFallback(),
            webFallbackEnabled: { [preferences] in preferences.webSearchFallbackEnabled }
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
        return AppEnvironment(container: container, usdaDB: usdaDB, offsDB: offsDB)
    }

    static func preview() throws -> AppEnvironment {
        try AppEnvironment(container: ModelContainerProvider.inMemory())
    }

    static func testing() throws -> AppEnvironment {
        try AppEnvironment(container: ModelContainerProvider.inMemory())
    }
}

nonisolated struct AppPreferences: Sendable {
    var webSearchFallbackEnabled: Bool

    static let `default` = AppPreferences(webSearchFallbackEnabled: false)
}

private func tryOpen<DB>(
    _ open: @escaping (URL) throws -> DB
) -> (URL?) -> DB? {
    { url in
        guard let url else { return nil }
        return try? open(url)
    }
}
