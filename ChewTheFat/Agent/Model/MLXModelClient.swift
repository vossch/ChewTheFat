import Foundation

#if canImport(MLXLLM) && canImport(MLXHuggingFace)
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// On-device inference client backed by Apple's MLX-Swift.
///
/// The container is loaded once via `warmUp()` and reused for every subsequent
/// `stream(_:)` call; each call creates a fresh `ChatSession`. Weights live in
/// Application Support (populated by `ModelBootstrapper`) and are reused via
/// the Hugging Face Hub cache — `useLatest: false` makes `loadContainer` a
/// near-instant no-op after first bootstrap.
nonisolated final class MLXModelClient: ModelClientProtocol, @unchecked Sendable {
    enum Failure: Error, LocalizedError {
        case notWarmedUp
        case weightsMissing

        var errorDescription: String? {
            switch self {
            case .notWarmedUp:
                return "MLX model not loaded. Call warmUp() before streaming."
            case .weightsMissing:
                return "Model weights missing from local cache. Run the bootstrapper first."
            }
        }
    }

    private let configuration: ModelConfiguration
    private let hubClient: HubClient
    private let state = ContainerState()

    init(
        modelId: String = ModelBootstrapper.defaultModelId,
        revision: String = ModelBootstrapper.defaultRevision
    ) throws {
        let cacheRoot = try ModelBootstrapper.applicationSupportModelsRoot()
        self.hubClient = HubClient(cache: HubCache(cacheDirectory: cacheRoot))

        let registered = LLMModelFactory.shared.configuration(id: modelId)
        if case .id(_, let existingRevision) = registered.id, existingRevision == revision {
            self.configuration = registered
        } else if case .id = registered.id {
            var copy = registered
            copy.id = .id(modelId, revision: revision)
            self.configuration = copy
        } else {
            self.configuration = registered
        }
    }

    func warmUp() async throws {
        if await state.container != nil { return }
        let downloader: Downloader = #hubDownloader(hubClient)
        let tokenizerLoader: TokenizerLoader = #huggingFaceTokenizerLoader()
        let container = try await LLMModelFactory.shared.loadContainer(
            from: downloader,
            using: tokenizerLoader,
            configuration: configuration,
            useLatest: false,
            progressHandler: { _ in }
        )
        await state.set(container)
    }

    func countTokens(_ text: String) async -> Int? {
        guard let container = await state.container else { return nil }
        let ids = await container.encode(text)
        return ids.count
    }

    nonisolated func stream(
        _ request: ModelRequest
    ) -> AsyncThrowingStream<ModelStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [state] in
                do {
                    guard let container = await state.container else {
                        throw Failure.notWarmedUp
                    }
                    try await Self.run(
                        request: request,
                        container: container,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Generation

    private static func run(
        request: ModelRequest,
        container: ModelContainer,
        continuation: AsyncThrowingStream<ModelStreamEvent, Error>.Continuation
    ) async throws {
        let history = buildHistory(from: request.messages)
        let lastUser = request.messages.last(where: { $0.role == .user })?.content ?? ""

        let params = mapParameters(request.parameters)
        let session: ChatSession
        if history.isEmpty {
            session = ChatSession(
                container,
                instructions: nonEmpty(request.systemPrompt),
                generateParameters: params
            )
        } else {
            session = ChatSession(
                container,
                instructions: nonEmpty(request.systemPrompt),
                history: history,
                generateParameters: params
            )
        }

        let handler = StreamingHandler()
        var finishReason: FinishReason = .stop
        for try await chunk in session.streamResponse(to: lastUser) {
            let events = await handler.feed(chunk)
            for event in events {
                if case .terminated = continuation.yield(event) { return }
            }
        }
        if Task.isCancelled { finishReason = .error }
        let tail = await handler.finish(reason: finishReason)
        for event in tail {
            if case .terminated = continuation.yield(event) { return }
        }
        continuation.finish()
    }

    private static func buildHistory(from messages: [ChatMessage]) -> [Chat.Message] {
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else {
            return messages.compactMap(Self.convert)
        }
        return messages.prefix(lastUserIndex).compactMap(Self.convert)
    }

    private static func convert(_ message: ChatMessage) -> Chat.Message? {
        switch message.role {
        case .system: return .system(message.content)
        case .user: return .user(message.content)
        case .assistant: return .assistant(message.content)
        case .tool: return .tool(message.content)
        }
    }

    private static func mapParameters(_ p: GenerationParameters) -> GenerateParameters {
        GenerateParameters(
            maxTokens: p.maxTokens > 0 ? p.maxTokens : nil,
            temperature: Float(p.temperature),
            topP: Float(p.topP)
        )
    }

    private static func nonEmpty(_ s: String) -> String? {
        s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : s
    }
}

/// Small actor wrapper so the synchronous `stream(_:)` entry point can share
/// container state without blocking its caller.
private actor ContainerState {
    var container: ModelContainer?

    func set(_ c: ModelContainer) {
        container = c
    }
}

extension ModelBootstrapper {
    /// Shared sandbox location for downloaded MLX weights.
    ///
    /// Both `ModelBootstrapper` and `MLXModelClient` point their `HubCache` at
    /// this directory so the client reuses whatever the bootstrapper already
    /// fetched. Kept `nonisolated` so it is callable from non-actor contexts.
    nonisolated static func applicationSupportModelsRoot() throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let models = support.appendingPathComponent("Models", isDirectory: true)
        try fm.createDirectory(at: models, withIntermediateDirectories: true)
        var mutable = models
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
        return models
    }
}

#endif
