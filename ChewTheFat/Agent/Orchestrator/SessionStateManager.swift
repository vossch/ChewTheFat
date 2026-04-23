import Foundation
import SwiftData

/// Tracks the active session, the user's session goal, and applies the
/// soft-redirect off-goal policy: if the user's input drifts away from the
/// declared goal, the orchestrator nudges back toward it but never refuses.
@MainActor
final class SessionStateManager {
    private(set) var session: Session
    private let evaluator: SessionGoalEvaluator
    private let sessions: SessionRepository

    init(session: Session, evaluator: SessionGoalEvaluator, sessions: SessionRepository) {
        self.session = session
        self.evaluator = evaluator
        self.sessions = sessions
    }

    var goal: SessionGoal {
        SessionGoal(rawValue: session.goal) ?? .general
    }

    func progress() async -> GoalProgress {
        let contract = SessionGoalContract.contract(for: goal)
        return await evaluator.evaluate(contract)
    }

    func appendUserMessage(_ text: String) throws -> Message {
        let message = Message(author: "user", textContent: text)
        try sessions.appendMessage(message, to: session)
        return message
    }

    func appendAssistantMessage(_ text: String?, widgets: [WidgetIntent]) throws -> Message {
        let message = Message(author: "assistant", textContent: text)
        try sessions.appendMessage(message, to: session)
        for (idx, widget) in widgets.enumerated() {
            let payload = try JSONEncoder().encode(widget)
            let widgetRow = MessageWidget(
                order: idx,
                type: widget.type,
                payload: payload,
                message: message
            )
            session.modelContext?.insert(widgetRow)
        }
        if !widgets.isEmpty { try session.modelContext?.save() }
        return message
    }

    /// Returns a soft-redirect note when the user input clearly mismatches
    /// the active goal. Returned text is appended to the model's system
    /// prompt rather than shown to the user.
    func redirectNote(for input: String) -> String? {
        let lower = input.lowercased()
        switch goal {
        case .logMeal where !lower.contains("eat") && !lower.contains("meal") && !lower.contains("food"):
            return nil
        case .logWeight where !lower.contains("weight") && !lower.contains("kg") && !lower.contains("lb"):
            return "Active goal is logWeight. Gently steer the user back toward recording today's weight."
        default:
            return nil
        }
    }
}
