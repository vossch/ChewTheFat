import Foundation

nonisolated struct ContextBudget: Sendable {
    let maxTokens: Int
    let reservedForResponse: Int

    var availableForPrompt: Int { max(0, maxTokens - reservedForResponse) }

    static let `default` = ContextBudget(maxTokens: 4096, reservedForResponse: 1024)

    /// Cheap, model-agnostic estimate (~4 chars per token).
    static func estimateTokens(in text: String) -> Int {
        max(1, text.count / 4)
    }
}
