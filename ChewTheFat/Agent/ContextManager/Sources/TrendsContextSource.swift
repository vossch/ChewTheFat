import Foundation

/// Surfaces the cached `Trends` blob in the agent system prompt. Pure read —
/// recomputation lives in `TrendsGenerator` and is triggered on foreground.
/// Empty windows produce no fragment so we don't bloat the prompt with zeros.
@MainActor
struct TrendsContextSource: ContextSourceProtocol {
    let trends: TrendsRepository

    nonisolated var name: String { "trends" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        var lines: [String] = []
        if let weight = try? trends.decodedWeight(), weight.entries > 0 {
            let formatted = String(format: "%.1f", weight.averageKg)
            lines.append("- 7-day avg weight: \(formatted) kg over \(weight.entries) entries")
        }
        if let macros = try? trends.decodedMacros(), macros.daysCovered > 0 {
            lines.append(
                "- 7-day daily avg: \(Int(macros.averageCalories.rounded())) kcal "
                + "(P \(Int(macros.averageProteinG.rounded()))g / "
                + "C \(Int(macros.averageCarbsG.rounded()))g / "
                + "F \(Int(macros.averageFatG.rounded()))g) "
                + "across \(macros.daysCovered) logged days"
            )
        }
        guard !lines.isEmpty else { return [] }
        let body = "Recent trends:\n" + lines.joined(separator: "\n")
        return [ContextFragment(label: "Trends", body: body, priority: .normal)]
    }
}
