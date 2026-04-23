import Foundation

protocol ModelClientProtocol: Sendable {
    func warmUp() async throws
    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelStreamEvent, Error>

    /// Returns the exact token count for `text` using the client's tokenizer,
    /// or `nil` when no tokenizer is available yet (e.g. not warmed up, or a
    /// stub client). Callers should fall back to `ContextBudget.estimateTokens`.
    func countTokens(_ text: String) async -> Int?
}

extension ModelClientProtocol {
    func countTokens(_ text: String) async -> Int? { nil }
}

extension ModelClientProtocol {
    func generate(_ request: ModelRequest) async throws -> ModelResponse {
        var text = ""
        var toolCalls: [ToolCallRequest] = []
        var widgets: [WidgetIntent] = []
        var reason: FinishReason = .stop
        for try await event in stream(request) {
            switch event {
            case .text(let chunk): text += chunk
            case .toolCall(let call): toolCalls.append(call)
            case .widget(let widget): widgets.append(widget)
            case .finished(let r): reason = r
            }
        }
        return ModelResponse(text: text, toolCalls: toolCalls, widgets: widgets, finishReason: reason)
    }
}
