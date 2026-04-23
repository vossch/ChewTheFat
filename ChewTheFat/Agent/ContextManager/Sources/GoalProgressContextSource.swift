import Foundation

@MainActor
struct GoalProgressContextSource: ContextSourceProtocol {
    let evaluator: SessionGoalEvaluator

    nonisolated var name: String { "goalProgress" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        let contract = SessionGoalContract.contract(for: request.goal)
        let progress = await evaluator.evaluate(contract)
        let collected = progress.collected.map { "- collected: \($0.label)" }
        let missing = progress.missing.map { "- MISSING: \($0.label)" }
        let body = """
        Session goal: \(request.goal.rawValue)
        Required field status:
        \((collected + missing).joined(separator: "\n"))
        Satisfied: \(progress.satisfied)
        """
        return [ContextFragment(label: "GoalProgress", body: body, priority: .critical)]
    }
}
