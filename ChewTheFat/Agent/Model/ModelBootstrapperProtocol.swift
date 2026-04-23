import Foundation

/// Streaming progress snapshot emitted by `ModelBootstrapperProtocol.progress()`.
nonisolated struct BootstrapProgress: Sendable, Equatable {
    var fractionCompleted: Double
    var bytesReceived: Int64
    var bytesTotal: Int64
    var description: String?

    static let idle = BootstrapProgress(
        fractionCompleted: 0,
        bytesReceived: 0,
        bytesTotal: 0,
        description: nil
    )

    static let complete = BootstrapProgress(
        fractionCompleted: 1,
        bytesReceived: 0,
        bytesTotal: 0,
        description: nil
    )
}

/// Typed errors surfaced from `fetch()`. The onboarding UI branches on these to
/// decide retry-vs-recover-vs-abort messaging (see Specs/implementation-plan.md M4).
nonisolated enum BootstrapError: Error, Sendable, Equatable {
    case network(String)
    case diskFull
    case cancelled
    case integrityCheckFailed(String)
    case notConfigured
}

/// Fetches on-device LLM weights from the Hugging Face Hub on first launch and
/// keeps them cached thereafter. See constitution 1.1.0 Principle I carve-out.
nonisolated protocol ModelBootstrapperProtocol: Sendable {
    var modelId: String { get }
    var isReady: Bool { get async }
    func progress() -> AsyncStream<BootstrapProgress>
    func fetch() async throws
    func cancel() async
}

/// No-op bootstrapper for SwiftUI previews, unit tests, and the Phase A build
/// that still uses `StubModelClient`. Always reports ready so gated UI paths
/// render without hitting the network.
nonisolated final class NullModelBootstrapper: ModelBootstrapperProtocol {
    let modelId: String

    init(modelId: String = "null") {
        self.modelId = modelId
    }

    var isReady: Bool { true }

    func progress() -> AsyncStream<BootstrapProgress> {
        AsyncStream { continuation in
            continuation.yield(.complete)
            continuation.finish()
        }
    }

    func fetch() async throws {}
    func cancel() async {}
}
