import Foundation

@MainActor
@Observable
final class MacroChartViewModel {
    struct Row: Identifiable, Hashable {
        let id: String
        let label: String
        let consumedGrams: Double
        let targetGrams: Double

        var progress: Double {
            guard targetGrams > 0 else { return 0 }
            return min(1.0, consumedGrams / targetGrams)
        }
    }

    private(set) var date: Date
    private(set) var rows: [Row] = []
    private(set) var consumedCalories: Int = 0
    private(set) var targetCalories: Int = 0

    private let foodLog: FoodLogRepository
    private let goals: GoalRepository

    init(date: Date, foodLog: FoodLogRepository, goals: GoalRepository) {
        self.date = date
        self.foodLog = foodLog
        self.goals = goals
    }

    func reload() {
        let logs = (try? foodLog.loggedFoods(on: date)) ?? []
        let totals = logs.reduce(NutritionFacts.zero) { acc, logged in
            guard let serving = logged.serving else { return acc }
            return acc + NutritionFacts(
                calories: serving.calories,
                proteinG: serving.proteinG,
                carbsG: serving.carbsG,
                fatG: serving.fatG,
                fiberG: serving.fiberG
            ).scaled(by: logged.quantity)
        }

        let userGoals = try? goals.current()
        let proteinTarget = userGoals?.proteinTargetG ?? 0
        let carbsTarget = userGoals?.carbsTargetG ?? 0
        let fatTarget = userGoals?.fatTargetG ?? 0
        self.targetCalories = userGoals?.calorieTarget ?? 0
        self.consumedCalories = Int(totals.calories.rounded())

        self.rows = [
            Row(id: "protein", label: "Protein", consumedGrams: totals.proteinG, targetGrams: proteinTarget),
            Row(id: "carbs",   label: "Carbs",   consumedGrams: totals.carbsG,   targetGrams: carbsTarget),
            Row(id: "fat",     label: "Fat",     consumedGrams: totals.fatG,     targetGrams: fatTarget),
        ]
    }
}
