import Foundation

/// Deterministic stub client used in tests, previews, and the Phase A build
/// before the real `MLXModelClient` is wired up. It echoes a canned reply
/// matching the latest user message and never emits tool calls or widgets.
nonisolated final class StubModelClient: ModelClientProtocol, @unchecked Sendable {
    private let preamble: String

    init(preamble: String = "(stub model) ") {
        self.preamble = preamble
    }

    func warmUp() async throws {}

    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelStreamEvent, Error> {
        let echo = request.messages
            .last(where: { $0.role == .user })?
            .content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reply = preamble + (echo.isEmpty ? "Hello." : "I heard: \(echo)")
        return AsyncThrowingStream { continuation in
            continuation.yield(.text(reply))
            continuation.yield(.finished(.stop))
            continuation.finish()
        }
    }
}
