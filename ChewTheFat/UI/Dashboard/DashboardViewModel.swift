import Foundation

/// Backs the home dashboard (US7). Owns the top-level state for Trajectory,
/// Today, Chat history, and nav chips. The individual widgets (macros, weight
/// graph, meal cards) reload themselves via `ModelChangeTicker`, so this
/// view-model is deliberately thin — it just exposes the ranges and session
/// list they depend on.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var today: Date
    private(set) var trajectoryRange: ClosedRange<Date>
    private(set) var meals: [MealType]
    private(set) var sessions: [Session] = []
    private(set) var hasAnyWeightHistory: Bool = false
    private(set) var latestWeightKg: Double?

    private let sessionsRepo: SessionRepository
    private let weightLog: WeightLogRepository

    init(
        sessions: SessionRepository,
        weightLog: WeightLogRepository,
        today: Date = .now,
        trajectoryWindowDays: Int = 90
    ) {
        let startOfDay = Calendar.current.startOfDay(for: today)
        self.today = startOfDay
        self.sessionsRepo = sessions
        self.weightLog = weightLog
        self.meals = MealType.allCases
        self.trajectoryRange = Self.range(
            endingAt: startOfDay,
            windowDays: trajectoryWindowDays
        )
    }

    func reload() {
        let list = (try? sessionsRepo.list(limit: 20)) ?? []
        self.sessions = list.filter { $0.goal != SessionGoal.onboarding.rawValue }

        let latest = try? weightLog.latest()
        self.latestWeightKg = latest?.weightKg
        self.hasAnyWeightHistory = latest != nil
    }

    /// Chat history is suppressed entirely when no non-onboarding sessions
    /// exist yet (edge case from spec §US7).
    var showsChatHistory: Bool { !sessions.isEmpty }

    /// Trajectory panel shows a "log your first weight" prompt until at least
    /// one WeightEntry exists (edge case from spec §US7).
    var showsTrajectoryEmptyState: Bool { !hasAnyWeightHistory }

    private static func range(endingAt end: Date, windowDays: Int) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -windowDays, to: end) ?? end
        return start...end
    }
}
