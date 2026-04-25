import Foundation
import SwiftData
@testable import ChewTheFat

/// Bundle of in-memory dependencies for orchestrator + tool tests. Avoids
/// `AppEnvironment.live()` so tests don't try to bootstrap MLX or open the
/// USDA / OFF reference DBs.
@MainActor
struct InMemoryEnvironment {
    let container: ModelContainer
    let context: ModelContext
    let profile: ProfileRepository
    let goals: GoalRepository
    let sessions: SessionRepository
    let foodLog: FoodLogRepository
    let foodCatalog: FoodCatalogRepository
    let weightLog: WeightLogRepository
    let memory: MemoryRepository
    let evaluator: SessionGoalEvaluator
    let knowledge: KnowledgeGraph

    init() throws {
        let container = try ModelContainerProvider.inMemory()
        self.container = container
        let ctx = container.mainContext
        self.context = ctx
        let profile = ProfileRepository(context: ctx)
        let goals = GoalRepository(context: ctx)
        self.profile = profile
        self.goals = goals
        self.sessions = SessionRepository(context: ctx)
        self.foodLog = FoodLogRepository(context: ctx)
        self.foodCatalog = FoodCatalogRepository(context: ctx)
        self.weightLog = WeightLogRepository(context: ctx)
        self.memory = MemoryRepository(context: ctx)
        self.evaluator = SessionGoalEvaluatorLive(profile: profile, goals: goals)
        self.knowledge = KnowledgeGraph()
    }

    func makeOrchestrator(
        session: Session,
        modelClient: ModelClientProtocol
    ) -> Orchestrator {
        let state = SessionStateManager(
            session: session,
            evaluator: evaluator,
            sessions: sessions
        )
        let assembler = ContextAssembler(
            tokenCounter: { text in await modelClient.countTokens(text) }
        )
        let contextManager = ContextManager(
            sources: [
                ProfileContextSource(profile: profile),
                GoalContextSource(goals: goals),
                GoalProgressContextSource(evaluator: evaluator),
                SessionContextSource(sessions: sessions),
                MemoryContextSource(memory: memory),
                KnowledgeContextSource(graph: knowledge),
            ],
            assembler: assembler
        )
        let dispatcher = ToolCallDispatcher()
        dispatcher.register(LogWeightTool(weightLog: weightLog, goals: goals))
        dispatcher.register(SetGoalsTool(goals: goals))
        dispatcher.register(SetProfileInfoTool(profile: profile))
        let turn = TurnHandler(model: modelClient, dispatcher: dispatcher)
        let resolver = WidgetIntentResolver(foodLog: foodLog, weightLog: weightLog)
        return Orchestrator(
            state: state,
            context: contextManager,
            turn: turn,
            resolver: resolver,
            toolSchemas: dispatcher.schemas
        )
    }

    /// Populates the profile + goals so the onboarding contract reports as
    /// satisfied. Use in tests that need to bypass onboarding gating.
    func completeOnboarding() throws {
        let p = UserProfile(
            age: 35,
            heightCm: 175,
            sex: "other",
            preferredUnits: "metric",
            activityLevel: "moderate",
            eulaAcceptedAt: Date()
        )
        try profile.save(p)

        try goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.45,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
    }
}
