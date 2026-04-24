import Foundation
import SwiftData

@MainActor
struct GoalRepository {
    let context: ModelContext

    func current() throws -> UserGoals? {
        let descriptor = FetchDescriptor<UserGoals>()
        return try context.fetch(descriptor).first
    }

    func save(_ goals: UserGoals) throws {
        if goals.modelContext == nil {
            context.insert(goals)
        }
        goals.updatedAt = .now
        try context.save()
    }

    enum ProjectionOutcome: Equatable {
        /// User is at (or within `toleranceKg` of) their ideal weight.
        case atGoal
        /// weeklyChangeKg is zero or points away from the goal — no ETA.
        case indefinite
        /// A concrete projected date and the per-day delta used.
        case projected(date: Date, perDayDeltaKg: Double)
    }

    /// Projects when the user reaches `idealWeightKg` from `currentWeightKg`
    /// at the configured `weeklyChangeKg`. Pure math — no side effects.
    ///
    /// - Parameters:
    ///   - currentWeightKg: latest logged weight; pass nil if unknown.
    ///   - reference: the date from which to project (usually `.now`).
    ///   - toleranceKg: distance within which we consider the user "at goal".
    func projectedGoal(
        currentWeightKg: Double?,
        reference: Date = .now,
        toleranceKg: Double = 0.25
    ) throws -> ProjectionOutcome {
        guard let goals = try current(),
              let ideal = goals.idealWeightKg,
              ideal > 0
        else { return .indefinite }

        guard let current = currentWeightKg, current.isFinite else {
            return .indefinite
        }

        let gap = ideal - current
        if abs(gap) <= toleranceKg { return .atGoal }

        let weekly = goals.weeklyChangeKg
        guard weekly.isFinite, abs(weekly) > 0.0001 else { return .indefinite }

        // Wrong direction: gap positive means user needs to gain, weekly must be positive.
        if (gap > 0 && weekly <= 0) || (gap < 0 && weekly >= 0) {
            return .indefinite
        }

        let perDay = weekly / 7.0
        let days = gap / perDay
        guard days.isFinite, days > 0, days < 365 * 5 else { return .indefinite }

        let seconds = days * 24 * 60 * 60
        let date = reference.addingTimeInterval(seconds)
        return .projected(date: date, perDayDeltaKg: perDay)
    }
}
