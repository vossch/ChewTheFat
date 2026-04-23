import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon

/// On-device inference client backed by Apple's MLX-Swift. Stubbed body
/// throws `notWired` until the SPM dep + model bundling lands in M2 Phase B.
///
/// Expected SPM products: `MLXLLM`, `MLXLMCommon` from
/// `https://github.com/ml-explore/mlx-swift-examples`.
final class MLXModelClient: ModelClientProtocol, @unchecked Sendable {
    enum Failure: Error { case notWired }

    init(modelId: String) throws {
        throw Failure.notWired
    }

    func warmUp() async throws { throw Failure.notWired }

    nonisolated func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: Failure.notWired)
        }
    }
}
#else
/// Placeholder when MLX-Swift is not yet linked. Real implementation arrives
/// in M2 Phase B alongside the SPM dependency and a bundled MLX model.
enum MLXModelClient {
    enum Failure: Error { case mlxUnavailable }
    static func make(modelId: String) throws -> ModelClientProtocol {
        throw Failure.mlxUnavailable
    }
}
#endif
