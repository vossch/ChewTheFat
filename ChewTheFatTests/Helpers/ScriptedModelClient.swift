import Foundation
@testable import ChewTheFat

/// Deterministic model client for tests. Emits a pre-canned script of
/// `ModelStreamEvent`s on each `stream(_:)` call. Successive calls advance
/// through the supplied scripts in order — useful for exercising tool-call
/// loops where the second turn (after the tool result) should produce a
/// final assistant reply.
final class ScriptedModelClient: ModelClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [[ModelStreamEvent]]
    private(set) var receivedRequests: [ModelRequest] = []

    init(scripts: [[ModelStreamEvent]]) {
        self.scripts = scripts
    }

    func warmUp() async throws {}

    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelStreamEvent, Error> {
        let events: [ModelStreamEvent] = lock.withLock {
            receivedRequests.append(request)
            return scripts.isEmpty ? [.finished(.stop)] : scripts.removeFirst()
        }
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
