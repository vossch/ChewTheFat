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

    /// Day-over-day kg delta beyond which we flag a weigh-in as anomalous
    /// even when the user has no active weekly target. Tuned for the typical
    /// hydration / sodium swing bound (~1.5 kg / 3.3 lb).
    static let anomalyThresholdKg: Double = 1.5

    /// Multiplier on the expected per-day rate above which a weigh-in is
    /// flagged as rapid. Keeps the heuristic proportional for users with
    /// aggressive targets (1 kg/week → per-day ~0.143 kg → rapid > ~0.43 kg).
    static let rapidMultiplier: Double = 3.0

    /// Number of days of zero change (within tolerance) before flagging a
    /// plateau, when the user has a nonzero weekly target.
    static let plateauWindowDays: Int = 14

    /// Distance below which a streak of weigh-ins counts as "no change".
    static let plateauToleranceKg: Double = 0.3

    /// Classifies a newly logged weight against recent history + the user's
    /// current weekly target. Pure function over its inputs (no I/O).
    func coachingFlag(
        newEntry: WeightEntry,
        history: [WeightEntry]
    ) throws -> CoachingFlag {
        let goals = try current()
        let weekly = goals?.weeklyChangeKg ?? 0
        let priors = history
            .filter { $0.id != newEntry.id && $0.date < newEntry.date }
            .sorted(by: { $0.date < $1.date })

        if let plateau = plateauFlag(newEntry: newEntry, priors: priors, weekly: weekly) {
            return plateau
        }
        if let rapid = rapidFlag(newEntry: newEntry, priors: priors, weekly: weekly) {
            return rapid
        }
        return .normal
    }

    private func plateauFlag(
        newEntry: WeightEntry,
        priors: [WeightEntry],
        weekly: Double
    ) -> CoachingFlag? {
        guard abs(weekly) > 0.0001 else { return nil }
        guard let oldest = priors.first else { return nil }
        let cal = Calendar.current
        let span = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: oldest.date),
            to: cal.startOfDay(for: newEntry.date)
        ).day ?? 0
        guard span >= Self.plateauWindowDays else { return nil }
        let delta = abs(newEntry.weightKg - oldest.weightKg)
        return delta <= Self.plateauToleranceKg ? .plateau : nil
    }

    private func rapidFlag(
        newEntry: WeightEntry,
        priors: [WeightEntry],
        weekly: Double
    ) -> CoachingFlag? {
        guard let previous = priors.last else { return nil }
        let days = max(
            1,
            Calendar.current.dateComponents(
                [.day],
                from: previous.date,
                to: newEntry.date
            ).day ?? 1
        )
        let delta = newEntry.weightKg - previous.weightKg
        let perDay = delta / Double(days)
        let absPerDay = abs(perDay)

        let expectedPerDay = abs(weekly) / 7.0
        let rapidByRate = expectedPerDay > 0 && absPerDay > Self.rapidMultiplier * expectedPerDay
        let rapidByAbsolute = absPerDay > Self.anomalyThresholdKg

        guard rapidByRate || rapidByAbsolute else { return nil }
        return perDay < 0 ? .rapidLoss : .rapidGain
    }
}
