import Foundation

/// Recomputes the `Trends` singleton from the last 7 days of weight + food
/// logs. Cheap by design — runs on the main actor on every foreground tick
/// where `Trends.isStale` is true. The generator only writes when something
/// actually changed; an empty 7-day window collapses to `.zero`-style payloads
/// rather than nil so downstream context sources can still describe state.
@MainActor
struct TrendsGenerator {
    let trends: TrendsRepository
    let weightLog: WeightLogRepository
    let foodLog: FoodLogRepository

    static let windowDays: Int = 7

    func recomputeIfStale(now: Date = .now) throws {
        let row = try trends.current()
        guard row.isStale else { return }
        try recompute(now: now)
    }

    func recompute(now: Date = .now) throws {
        let cal = Calendar.current
        let end = cal.startOfDay(for: now)
        guard let start = cal.date(byAdding: .day, value: -(Self.windowDays - 1), to: end) else { return }

        let entries = try weightLog.entries(in: start...end)
        if let summary = Self.summarize(weights: entries) {
            try trends.writeWeight(payload: summary, rangeStart: start, rangeEnd: end)
        } else {
            try trends.writeWeight(
                payload: TrendsWeightSummary(averageKg: 0, entries: 0, firstDate: nil, lastDate: nil),
                rangeStart: start,
                rangeEnd: end
            )
        }

        let logs = try foodLog.loggedFoods(in: start...end)
        let macros = Self.summarize(loggedFoods: logs, windowDays: Self.windowDays)
        try trends.writeMacros(payload: macros, rangeStart: start, rangeEnd: end)

        try trends.clearStale()
    }

    static func summarize(weights: [WeightEntry]) -> TrendsWeightSummary? {
        guard !weights.isEmpty else { return nil }
        let total = weights.reduce(0.0) { $0 + $1.weightKg }
        let avg = total / Double(weights.count)
        let sorted = weights.sorted(by: { $0.date < $1.date })
        return TrendsWeightSummary(
            averageKg: avg,
            entries: weights.count,
            firstDate: sorted.first?.date,
            lastDate: sorted.last?.date
        )
    }

    static func summarize(loggedFoods: [LoggedFood], windowDays: Int) -> TrendsMacroSummary {
        guard !loggedFoods.isEmpty, windowDays > 0 else {
            return TrendsMacroSummary(
                averageCalories: 0,
                averageProteinG: 0,
                averageCarbsG: 0,
                averageFatG: 0,
                daysCovered: 0
            )
        }
        var totals = NutritionFacts.zero
        var distinctDays = Set<Date>()
        for entry in loggedFoods {
            guard let serving = entry.serving else { continue }
            let perServing = NutritionFacts(
                calories: serving.calories,
                proteinG: serving.proteinG,
                carbsG: serving.carbsG,
                fatG: serving.fatG,
                fiberG: serving.fiberG
            )
            totals = totals + perServing.scaled(by: entry.quantity)
            distinctDays.insert(entry.date)
        }
        let divisor = Double(windowDays)
        return TrendsMacroSummary(
            averageCalories: totals.calories / divisor,
            averageProteinG: totals.proteinG / divisor,
            averageCarbsG: totals.carbsG / divisor,
            averageFatG: totals.fatG / divisor,
            daysCovered: distinctDays.count
        )
    }
}
