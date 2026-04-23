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
        self.points = pastPoints + projectionStub(from: pastPoints)
        self.idealWeightKg = (try? goals.current())?.idealWeightKg
    }

    /// M3 stub: if the user has a goal and at least one weight entry, draw a
    /// 14-day linear projection toward the idealWeightKg. The real heuristic
    /// lands in M4 alongside the onboarding goal-date math.
    private func projectionStub(from past: [Point]) -> [Point] {
        guard let last = past.last else { return [] }
        let target = (try? goals.current())?.idealWeightKg
        guard let target, target != last.weightKg else { return [] }

        let calendar = Calendar.current
        let horizonDays = 14
        let delta = (target - last.weightKg) / Double(horizonDays)
        var out: [Point] = []
        for day in 1...horizonDays {
            guard let next = calendar.date(byAdding: .day, value: day, to: last.date) else { continue }
            out.append(Point(
                id: next,
                date: next,
                weightKg: last.weightKg + delta * Double(day),
                isProjected: true
            ))
        }
        return out
    }
}
