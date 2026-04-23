import Foundation

#if canImport(MLXHuggingFace)
import HuggingFace
import MLXHuggingFace
import MLXLMCommon

/// Fetches MLX model weights from the Hugging Face Hub into Application Support
/// and exposes progress for onboarding UI. Idempotent — subsequent calls to
/// `fetch()` return immediately once the snapshot is present on disk.
///
/// On-disk layout follows the Hub cache convention inside the app sandbox:
///
///     <Application Support>/Models/models--<org>--<name>/snapshots/<revision>/
///
/// The `Models/` root is marked `isExcludedFromBackup` so the weights do not
/// propagate to iCloud backups (see research.md §1 decision 2026-04-22).
actor ModelBootstrapper: ModelBootstrapperProtocol {
    nonisolated static let defaultModelId = "mlx-community/gemma-3-1b-it-qat-4bit"
    nonisolated static let defaultRevision = "main"

    nonisolated private static let downloadPatterns = [
        "*.safetensors",
        "*.json",
        "*.jinja",
        "tokenizer*",
    ]

    nonisolated let modelId: String
    private let revision: String
    private let cacheRoot: URL
    private let hubClient: HubClient

    private var fetchTask: Task<Void, Error>?
    private var continuations: [UUID: AsyncStream<BootstrapProgress>.Continuation] = [:]
    private var latestProgress: BootstrapProgress = .idle
    private var readyFlag: Bool = false

    init(
        modelId: String = defaultModelId,
        revision: String = defaultRevision
    ) throws {
        self.modelId = modelId
        self.revision = revision
        self.cacheRoot = try Self.applicationSupportModelsRoot()
        self.hubClient = HubClient(cache: HubCache(cacheDirectory: self.cacheRoot))
    }

    var isReady: Bool {
        if readyFlag { return true }
        if Self.snapshotHasWeights(cacheRoot: cacheRoot, modelId: modelId) {
            readyFlag = true
            return true
        }
        return false
    }

    nonisolated func progress() -> AsyncStream<BootstrapProgress> {
        AsyncStream { continuation in
            let id = UUID()
            Task { [weak self] in
                await self?.addContinuation(id: id, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    func fetch() async throws {
        if isReady { return }
        if let fetchTask {
            try await fetchTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            try await self.runFetch()
        }
        fetchTask = task
        do {
            try await task.value
        } catch {
            fetchTask = nil
            throw Self.mapError(error)
        }
        fetchTask = nil
    }

    func cancel() {
        fetchTask?.cancel()
        fetchTask = nil
        for cont in continuations.values {
            cont.finish()
        }
        continuations.removeAll()
    }

    // MARK: - Private

    private func addContinuation(
        id: UUID,
        continuation: AsyncStream<BootstrapProgress>.Continuation
    ) {
        continuations[id] = continuation
        continuation.yield(latestProgress)
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func publish(_ progress: BootstrapProgress) {
        latestProgress = progress
        for cont in continuations.values {
            cont.yield(progress)
        }
    }

    private func finishStreams() {
        for cont in continuations.values {
            cont.finish()
        }
        continuations.removeAll()
    }

    private func runFetch() async throws {
        let downloader: Downloader = #hubDownloader(hubClient)
        let id = modelId
        let revision = revision
        let resolved = try await downloader.download(
            id: id,
            revision: revision,
            matching: Self.downloadPatterns,
            useLatest: false,
            progressHandler: { [weak self] progress in
                let snapshot = BootstrapProgress(
                    fractionCompleted: progress.fractionCompleted,
                    bytesReceived: progress.completedUnitCount,
                    bytesTotal: progress.totalUnitCount,
                    description: progress.localizedDescription
                )
                Task { await self?.publish(snapshot) }
            }
        )
        try Self.markExcludedFromBackup(resolved)
        readyFlag = true
        publish(.complete)
        finishStreams()
    }

    // MARK: - Filesystem helpers

    nonisolated private static func markExcludedFromBackup(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }

    nonisolated private static func snapshotHasWeights(cacheRoot: URL, modelId: String) -> Bool {
        let normalized = modelId.replacingOccurrences(of: "/", with: "--")
        let snapshots = cacheRoot
            .appendingPathComponent("models--\(normalized)", isDirectory: true)
            .appendingPathComponent("snapshots", isDirectory: true)
        let fm = FileManager.default
        guard let revs = try? fm.contentsOfDirectory(
            at: snapshots,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        for rev in revs {
            guard let files = try? fm.contentsOfDirectory(
                at: rev,
                includingPropertiesForKeys: nil
            ) else { continue }
            if files.contains(where: { $0.pathExtension == "safetensors" }) {
                return true
            }
        }
        return false
    }

    nonisolated private static func mapError(_ error: Error) -> BootstrapError {
        if error is CancellationError { return .cancelled }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorCancelled { return .cancelled }
            return .network(nsError.localizedDescription)
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == 28 {
            return .diskFull
        }
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteOutOfSpaceError {
            return .diskFull
        }
        return .network(nsError.localizedDescription)
    }
}

#endif
