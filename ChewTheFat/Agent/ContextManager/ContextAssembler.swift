import Foundation

struct AssembledContext: Sendable {
    let systemPrompt: String
    let estimatedTokens: Int
    let included: [String]
    let dropped: [String]
}

typealias TokenCounter = @Sendable (String) async -> Int?

nonisolated struct ContextAssembler: Sendable {
    let budget: ContextBudget
    let tokenCounter: TokenCounter?

    init(budget: ContextBudget = .default, tokenCounter: TokenCounter? = nil) {
        self.budget = budget
        self.tokenCounter = tokenCounter
    }

    func assemble(fragments: [ContextFragment]) async -> AssembledContext {
        let scored = await scoreFragments(fragments)
        let ranked = scored.sorted { lhs, rhs in
            if lhs.fragment.priority != rhs.fragment.priority {
                return lhs.fragment.priority > rhs.fragment.priority
            }
            return false
        }
        var remaining = budget.availableForPrompt
        var kept: [ScoredFragment] = []
        var dropped: [ScoredFragment] = []
        for scored in ranked {
            if scored.tokens <= remaining {
                remaining -= scored.tokens
                kept.append(scored)
            } else {
                dropped.append(scored)
            }
        }
        let prompt = kept
            .map { "## \($0.fragment.label)\n\($0.fragment.body)" }
            .joined(separator: "\n\n")
        return AssembledContext(
            systemPrompt: prompt,
            estimatedTokens: budget.availableForPrompt - remaining,
            included: kept.map(\.fragment.label),
            dropped: dropped.map(\.fragment.label)
        )
    }

    private func scoreFragments(_ fragments: [ContextFragment]) async -> [ScoredFragment] {
        guard let counter = tokenCounter else {
            return fragments.map { ScoredFragment(fragment: $0, tokens: $0.estimatedTokens) }
        }
        var result: [ScoredFragment] = []
        result.reserveCapacity(fragments.count)
        for fragment in fragments {
            let exact = await counter(fragment.body)
            result.append(ScoredFragment(fragment: fragment, tokens: exact ?? fragment.estimatedTokens))
        }
        return result
    }

    private struct ScoredFragment: Sendable {
        let fragment: ContextFragment
        let tokens: Int
    }
}
