import Foundation

protocol ModelClientProtocol: Sendable {
    func warmUp() async throws
    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelStreamEvent, Error>
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
