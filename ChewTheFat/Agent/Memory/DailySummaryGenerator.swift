import Foundation

/// Heuristic-only end-of-day summary. Walks yesterday's `LoggedFood` and
/// `WeightEntry` rows, formats a single short string, and writes it as a
/// `Memory` row tagged `dailySummary`. The model-gated v2 will compose a
/// richer narrative from the same inputs; v1 just stamps the totals so the
/// memory context source has something to recall.
@MainActor
struct DailySummaryGenerator {
    let memory: MemoryRepository
    let foodLog: FoodLogRepository
    let weightLog: WeightLogRepository
    let preferences: AppPreferences

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Foreground fallback: if a day has gone by without a summary being
    /// written, generate one for the most recent uncovered day. Runs on every
    /// scenePhase active tick — cheap because we early-out as soon as we
    /// notice the marker matches "yesterday".
    func runIfNeeded(now: Date = .now) {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now)) else { return }
        let key = Self.dayKeyFormatter.string(from: yesterday)
        guard preferences.lastDailySummaryDay != key else { return }
        try? generate(for: yesterday)
        preferences.lastDailySummaryDay = key
    }

    func generate(for day: Date) throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) else { return }

        let logs = try foodLog.loggedFoods(in: start...end)
        let weights = try weightLog.entries(in: start...end)

        let summary = Self.compose(for: day, logs: logs, weights: weights)
        guard !summary.isEmpty else { return }
        _ = try memory.add(content: summary, category: "dailySummary")
    }

    static func compose(
        for day: Date,
        logs: [LoggedFood],
        weights: [WeightEntry]
    ) -> String {
        let dateLabel = dayKeyFormatter.string(from: day)
        var parts: [String] = ["Daily summary \(dateLabel):"]

        if logs.isEmpty {
            parts.append("no meals logged")
        } else {
            var totals = NutritionFacts.zero
            var byMeal: [String: Int] = [:]
            for entry in logs {
                if let serving = entry.serving {
                    let perServing = NutritionFacts(
                        calories: serving.calories,
                        proteinG: serving.proteinG,
                        carbsG: serving.carbsG,
                        fatG: serving.fatG,
                        fiberG: serving.fiberG
                    )
                    totals = totals + perServing.scaled(by: entry.quantity)
                }
                byMeal[entry.meal, default: 0] += 1
            }
            let mealCount = logs.count
            parts.append("\(mealCount) item\(mealCount == 1 ? "" : "s") logged")
            parts.append(
                "\(Int(totals.calories.rounded())) kcal "
                + "(P \(Int(totals.proteinG.rounded()))g / "
                + "C \(Int(totals.carbsG.rounded()))g / "
                + "F \(Int(totals.fatG.rounded()))g)"
            )
        }

        if let weight = weights.last {
            let formatted = String(format: "%.1f", weight.weightKg)
            parts.append("weighed \(formatted) kg")
        }
        return parts.joined(separator: " — ")
    }
}
