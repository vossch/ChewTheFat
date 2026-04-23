import Foundation

/// Drives a single user → model → tools → model loop. Streams `TurnEvent`s
/// to the caller. Does NOT persist anything; that is the orchestrator's job
/// because persistence requires `@MainActor`.
struct TurnHandler {
    let model: ModelClientProtocol
    let dispatcher: ToolCallDispatcher
    let maxToolHops: Int

    init(model: ModelClientProtocol, dispatcher: ToolCallDispatcher, maxToolHops: Int = 4) {
        self.model = model
        self.dispatcher = dispatcher
        self.maxToolHops = maxToolHops
    }

    @MainActor
    func run(initialRequest: ModelRequest) -> AsyncThrowingStream<TurnEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var request = initialRequest
                var hop = 0
                outer: while hop <= maxToolHops {
                    var collectedText = ""
                    var pendingToolCalls: [ToolCallRequest] = []
                    var widgets: [WidgetIntent] = []
                    var finishReason: FinishReason = .stop

                    do {
                        for try await event in model.stream(request) {
                            switch event {
                            case .text(let chunk):
                                collectedText += chunk
                                continuation.yield(.textChunk(chunk))
                            case .toolCall(let call):
                                pendingToolCalls.append(call)
                            case .widget(let widget):
                                widgets.append(widget)
                                continuation.yield(.widget(widget))
                            case .finished(let reason):
                                finishReason = reason
                            }
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }

                    if pendingToolCalls.isEmpty {
                        continuation.yield(.completed(text: collectedText, widgets: widgets, finishReason: finishReason))
                        continuation.finish()
                        return
                    }

                    var followUpMessages = request.messages
                    if !collectedText.isEmpty {
                        followUpMessages.append(ChatMessage(role: .assistant, content: collectedText))
                    }

                    for call in pendingToolCalls {
                        continuation.yield(.toolCallStarted(call))
                        let outcome = await dispatcher.dispatch(call)
                        continuation.yield(.toolCallFinished(outcome))
                        if let widget = outcome.widget {
                            widgets.append(widget)
                            continuation.yield(.widget(widget))
                        }
                        followUpMessages.append(ChatMessage(
                            role: .tool,
                            content: outcome.responseJSON,
                            toolCallId: outcome.call.id
                        ))
                    }

                    request = ModelRequest(
                        systemPrompt: request.systemPrompt,
                        messages: followUpMessages,
                        tools: request.tools,
                        widgetSchemas: request.widgetSchemas,
                        parameters: request.parameters
                    )
                    hop += 1
                    continue outer
                }

                continuation.yield(.completed(text: "", widgets: [], finishReason: .stop))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum TurnEvent: Sendable {
    case textChunk(String)
    case widget(WidgetIntent)
    case toolCallStarted(ToolCallRequest)
    case toolCallFinished(ToolCallOutcome)
    case completed(text: String, widgets: [WidgetIntent], finishReason: FinishReason)
}
