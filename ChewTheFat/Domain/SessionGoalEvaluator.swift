import Foundation

protocol SessionGoalEvaluator: Sendable {
    func evaluate(_ contract: SessionGoalContract) async -> GoalProgress
}
