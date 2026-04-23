import Foundation

@MainActor
struct SessionContextSource: ContextSourceProtocol {
    let sessions: SessionRepository
    let messageLimit: Int

    init(sessions: SessionRepository, messageLimit: Int = 12) {
        self.sessions = sessions
        self.messageLimit = messageLimit
    }

    nonisolated var name: String { "session" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        guard let session = try? sessions.find(id: request.sessionId) else { return [] }
        let recent = session.messages
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(messageLimit)
            .reversed()
        let lines = recent.compactMap { msg -> String? in
            guard let text = msg.textContent, !text.isEmpty else { return nil }
            return "\(msg.author): \(text)"
        }
        guard !lines.isEmpty else { return [] }
        let body = "Recent turns in session \"\(session.name)\":\n" + lines.joined(separator: "\n")
        return [ContextFragment(label: "Session", body: body, priority: .high)]
    }
}
