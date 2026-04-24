import Foundation

/// Drives the chat surface. Consumes `Orchestrator.TurnEvent` streams,
/// coalescing `.textChunk` into the trailing assistant bubble and inserting
/// `.widget` intents inline. Tool-call events are intentionally swallowed —
/// the constitution (Principle IV) forbids surfacing tool calls or chain-of-
/// thought to the user.
@MainActor
@Observable
final class ChatViewModel {
    enum Status: Equatable {
        case idle
        case sending
        case streaming
        case error(String)
    }

    /// One renderable item in the chat list. A single assistant turn can
    /// produce a `.text` entry, any number of `.widget` entries, or both.
    enum DisplayMessage: Identifiable, Equatable {
        case text(id: UUID, author: Author, body: String)
        case widget(id: UUID, intent: WidgetIntent)

        enum Author: Equatable { case user, assistant, system }

        var id: UUID {
            switch self {
            case .text(let id, _, _): return id
            case .widget(let id, _): return id
            }
        }
    }

    private(set) var messages: [DisplayMessage] = []
    private(set) var status: Status = .idle
    /// True while the orchestrator has accepted the turn but no text chunk
    /// has arrived yet. UI binds this to a typing indicator per FR-027.
    var isTyping: Bool { status == .sending }

    private let orchestrator: OrchestratorProtocol
    let session: Session
    private var sendTask: Task<Void, Never>?
    private var kickoffTask: Task<Void, Never>?
    private var hasPrimed = false

    init(orchestrator: OrchestratorProtocol, session: Session) {
        self.orchestrator = orchestrator
        self.session = session
        hydrateFromSession()
    }

    /// Fires an orchestrator kickoff turn when the session has no messages
    /// yet, letting the model author the opening greeting itself. Safe to
    /// call repeatedly — a guard prevents duplicate runs.
    func primeIfNeeded() {
        guard !hasPrimed, messages.isEmpty, session.messages.isEmpty, status == .idle else { return }
        hasPrimed = true
        status = .sending
        let orchestrator = self.orchestrator
        kickoffTask?.cancel()
        kickoffTask = Task { [weak self] in
            var assistantBubbleId: UUID?
            do {
                for try await event in orchestrator.kickoff() {
                    guard let self else { return }
                    if Task.isCancelled { return }
                    switch event {
                    case .textChunk(let chunk):
                        self.status = .streaming
                        assistantBubbleId = self.appendOrExtendAssistantText(chunk, id: assistantBubbleId)
                    case .widget(let intent):
                        self.status = .streaming
                        self.messages.append(.widget(id: UUID(), intent: intent))
                    case .toolCallStarted, .toolCallFinished, .completed:
                        break
                    }
                }
                guard let self else { return }
                self.status = .idle
            } catch {
                guard let self else { return }
                self.status = .error(error.localizedDescription)
                self.hasPrimed = false
            }
        }
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, status != .sending, status != .streaming else { return }

        messages.append(.text(id: UUID(), author: .user, body: trimmed))
        status = .sending

        let orchestrator = self.orchestrator
        sendTask?.cancel()
        sendTask = Task { [weak self] in
            var assistantBubbleId: UUID?
            do {
                for try await event in orchestrator.send(text: trimmed) {
                    guard let self else { return }
                    if Task.isCancelled { return }
                    switch event {
                    case .textChunk(let chunk):
                        self.status = .streaming
                        assistantBubbleId = self.appendOrExtendAssistantText(chunk, id: assistantBubbleId)
                    case .widget(let intent):
                        self.status = .streaming
                        self.messages.append(.widget(id: UUID(), intent: intent))
                    case .toolCallStarted, .toolCallFinished:
                        // Deliberately invisible to the user.
                        break
                    case .completed:
                        break
                    }
                }
                guard let self else { return }
                self.status = .idle
            } catch {
                guard let self else { return }
                self.status = .error(error.localizedDescription)
            }
        }
    }

    func cancelInFlight() {
        sendTask?.cancel()
        sendTask = nil
        if status == .sending || status == .streaming { status = .idle }
    }

    private func appendOrExtendAssistantText(_ chunk: String, id existing: UUID?) -> UUID {
        if let existing, let idx = messages.firstIndex(where: { $0.id == existing }) {
            if case .text(let id, let author, let body) = messages[idx] {
                messages[idx] = .text(id: id, author: author, body: body + chunk)
                return id
            }
        }
        let id = UUID()
        messages.append(.text(id: id, author: .assistant, body: chunk))
        return id
    }

    private func hydrateFromSession() {
        let ordered = session.messages.sorted(by: { $0.createdAt < $1.createdAt })
        for message in ordered {
            let author = Self.author(from: message.author)
            if let text = message.textContent, !text.isEmpty {
                messages.append(.text(id: message.id, author: author, body: text))
            }
            let widgets = message.widgets.sorted(by: { $0.order < $1.order })
            for row in widgets {
                if let intent = WidgetIntentDecoder.decode(row) {
                    messages.append(.widget(id: row.id, intent: intent))
                }
            }
        }
    }

    private static func author(from raw: String) -> DisplayMessage.Author {
        switch raw {
        case "user": return .user
        case "assistant": return .assistant
        default: return .system
        }
    }
}
