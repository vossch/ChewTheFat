import Foundation

@MainActor
struct GoalContextSource: ContextSourceProtocol {
    let goals: GoalRepository

    nonisolated var name: String { "goal" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        guard let g = try? goals.current() else { return [] }
        var lines: [String] = [
            "- method: \(g.method)",
            "- weeklyChangeKg: \(g.weeklyChangeKg)",
            "- calorieTarget: \(g.calorieTarget) kcal",
            "- protein: \(Int(g.proteinTargetG)) g",
            "- carbs: \(Int(g.carbsTargetG)) g",
            "- fat: \(Int(g.fatTargetG)) g",
        ]
        if let ideal = g.idealWeightKg {
            lines.append("- idealWeightKg: \(ideal)")
        }
        let body = "User nutrition goals:\n" + lines.joined(separator: "\n")
        return [ContextFragment(label: "Goals", body: body, priority: .high)]
    }
}
