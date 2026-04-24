import Foundation

@MainActor
@Observable
final class WeightGraphViewModel {
    struct Point: Identifiable, Hashable {
        let id: Date
        let date: Date
        let weightKg: Double
        let isProjected: Bool
    }

    private(set) var points: [Point] = []
    private(set) var idealWeightKg: Double?
    private(set) var range: ClosedRange<Date>

    private let weightLog: WeightLogRepository
    private let goals: GoalRepository

    init(range: ClosedRange<Date>, weightLog: WeightLogRepository, goals: GoalRepository) {
        self.range = range
        self.weightLog = weightLog
        self.goals = goals
    }

    func reload() {
        let past = (try? weightLog.entries(in: range)) ?? []
        let pastPoints = past.map {
            Point(id: $0.date, date: $0.date, weightKg: $0.weightKg, isProjected: false)
        }
        self.points = pastPoints + projection(from: pastPoints)
        self.idealWeightKg = (try? goals.current())?.idealWeightKg
    }

    /// Linear projection anchored at the most recent weight entry, using the
    /// per-day rate GoalRepository derives from weeklyChangeKg. Stops when the
    /// trajectory reaches idealWeightKg.
    private func projection(from past: [Point]) -> [Point] {
        guard let last = past.last else { return [] }
        guard let outcome = try? goals.projectedGoal(
            currentWeightKg: last.weightKg,
            reference: last.date
        ) else { return [] }

        switch outcome {
        case .atGoal, .indefinite:
            return []
        case .projected(let endDate, let perDay):
            guard let ideal = (try? goals.current())?.idealWeightKg else { return [] }
            let calendar = Calendar.current
            let totalDays = max(
                1,
                calendar.dateComponents([.day], from: last.date, to: endDate).day ?? 1
            )
            let sampleCount = min(max(totalDays, 4), 60)
            let step = max(1, totalDays / sampleCount)
            var out: [Point] = []
            var day = step
            while day <= totalDays {
                guard let next = calendar.date(byAdding: .day, value: day, to: last.date) else { break }
                let projectedWeight = last.weightKg + perDay * Double(day)
                let clamped = clamp(projectedWeight, toward: ideal, from: last.weightKg)
                out.append(Point(id: next, date: next, weightKg: clamped, isProjected: true))
                day += step
            }
            if out.last?.date != endDate {
                out.append(Point(id: endDate, date: endDate, weightKg: ideal, isProjected: true))
            }
            return out
        }
    }

    /// Prevents a rounding overshoot past the goal line.
    private func clamp(_ value: Double, toward goal: Double, from start: Double) -> Double {
        if start < goal { return min(value, goal) }
        return max(value, goal)
    }
}
