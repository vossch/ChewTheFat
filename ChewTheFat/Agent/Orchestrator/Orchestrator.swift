import Foundation

@MainActor
final class Orchestrator: OrchestratorProtocol {
    private let state: SessionStateManager
    private let context: ContextManager
    private let turn: TurnHandler
    private let resolver: WidgetIntentResolver
    private let toolSchemas: [ToolSchema]

    init(
        state: SessionStateManager,
        context: ContextManager,
        turn: TurnHandler,
        resolver: WidgetIntentResolver,
        toolSchemas: [ToolSchema]
    ) {
        self.state = state
        self.context = context
        self.turn = turn
        self.resolver = resolver
        self.toolSchemas = toolSchemas
    }

    func send(text: String) -> AsyncThrowingStream<TurnEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    _ = try state.appendUserMessage(text)
                } catch {
                    continuation.finish(throwing: error)
                    return
                }

                let request = await buildRequest(latestUserText: text)
                var streamedText = ""
                var emittedWidgets: [WidgetIntent] = []

                for try await event in turn.run(initialRequest: request) {
                    switch event {
                    case .textChunk(let chunk):
                        streamedText += chunk
                    case .widget(let intent):
                        if let resolved = resolver.resolve(intent) {
                            emittedWidgets.append(resolved)
                        }
                    case .toolCallStarted, .toolCallFinished:
                        // intentionally not surfaced to UI
                        break
                    case .completed(let text, _, _):
                        let finalText = text.isEmpty ? streamedText : text
                        do {
                            _ = try state.appendAssistantMessage(
                                finalText.isEmpty ? nil : finalText,
                                widgets: emittedWidgets
                            )
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func buildRequest(latestUserText: String) async -> ModelRequest {
        let assembled = await context.prompt(
            for: ContextRequest(sessionId: state.session.id, goal: state.goal)
        )
        var systemPrompt = """
        You are ChewTheFat, an on-device food-logging coach. You speak through chat and
        emit interactive widgets when helpful. Never reveal tool calls, internal IDs, or
        chain-of-thought to the user.

        Current session goal: \(state.goal.rawValue).

        \(assembled.systemPrompt)
        """
        if let redirect = state.redirectNote(for: latestUserText) {
            systemPrompt += "\n\nGuidance: \(redirect)"
        }

        var history: [ChatMessage] = []
        for message in state.session.messages.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let text = message.textContent, !text.isEmpty else { continue }
            let role: ChatMessage.Role = message.author == "user" ? .user : .assistant
            history.append(ChatMessage(role: role, content: text))
        }

        return ModelRequest(
            systemPrompt: systemPrompt,
            messages: history,
            tools: toolSchemas
        )
    }
}
