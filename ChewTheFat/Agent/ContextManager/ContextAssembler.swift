import Foundation

struct AssembledContext: Sendable {
    let systemPrompt: String
    let estimatedTokens: Int
    let included: [String]
    let dropped: [String]
}

nonisolated struct ContextAssembler: Sendable {
    let budget: ContextBudget

    init(budget: ContextBudget = .default) {
        self.budget = budget
    }

    func assemble(fragments: [ContextFragment]) -> AssembledContext {
        let ranked = fragments.sorted { $0.priority > $1.priority }
        var remaining = budget.availableForPrompt
        var kept: [ContextFragment] = []
        var dropped: [ContextFragment] = []
        for fragment in ranked {
            if fragment.estimatedTokens <= remaining {
                remaining -= fragment.estimatedTokens
                kept.append(fragment)
            } else {
                dropped.append(fragment)
            }
        }
        let prompt = kept
            .sorted(by: { lhs, rhs in
                if lhs.priority == rhs.priority { return false }
                return lhs.priority > rhs.priority
            })
            .map { "## \($0.label)\n\($0.body)" }
            .joined(separator: "\n\n")
        return AssembledContext(
            systemPrompt: prompt,
            estimatedTokens: budget.availableForPrompt - remaining,
            included: kept.map(\.label),
            dropped: dropped.map(\.label)
        )
    }
}
