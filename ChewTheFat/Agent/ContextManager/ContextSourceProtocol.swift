import Foundation

nonisolated struct ContextRequest: Sendable {
    let sessionId: UUID
    let goal: SessionGoal
    let now: Date

    init(sessionId: UUID, goal: SessionGoal, now: Date = .now) {
        self.sessionId = sessionId
        self.goal = goal
        self.now = now
    }
}

nonisolated struct ContextFragment: Sendable {
    enum Priority: Int, Sendable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let label: String
    let body: String
    let priority: Priority
    let estimatedTokens: Int

    init(label: String, body: String, priority: Priority = .normal) {
        self.label = label
        self.body = body
        self.priority = priority
        self.estimatedTokens = ContextBudget.estimateTokens(in: body)
    }
}

protocol ContextSourceProtocol: Sendable {
    var name: String { get }
    func contribute(for request: ContextRequest) async -> [ContextFragment]
}
