import SwiftUI

/// Shown after the user finishes the scripted FRE if the MLX weights have not
/// yet finished downloading. Streams `BootstrapProgress` until completion, then
/// invokes `onReady()`. The FRE screens kick the fetch off when EULA is
/// accepted; this view never initiates the download itself — it just waits.
@MainActor
struct DownloadingAIView: View {
    let bootstrapper: ModelBootstrapperProtocol
    let onReady: () -> Void

    @State private var progress: BootstrapProgress = .idle
    @State private var phase: Phase = .waiting
    @State private var fetchTask: Task<Void, Never>?

    enum Phase: Equatable {
        case waiting
        case ready
        case failed(BootstrapError)
    }

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            content
                .padding(Spacing.lg)
        }
        .task { await observe() }
        .onDisappear { fetchTask?.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .waiting:
            waitingView
        case .ready:
            readyView
        case .failed(let error):
            failedView(error)
        }
    }

    private var waitingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(AppColor.textPrimary)
            VStack(spacing: Spacing.sm) {
                Text("Downloading AI")
                    .font(Typography.title)
                    .foregroundStyle(AppColor.textPrimary)
                Text(progressSubtitle)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
            }
            Text("Unlike most AI chat apps, ChewTheFat runs entirely locally, keeping your data on your device. AI models are large. It might take a few minutes.")
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
        }
    }

    private var readyView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: AppIcon.check)
                .font(.system(size: IconSize.lg))
                .foregroundStyle(AppColor.success)
            Text("AI ready")
                .font(Typography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Button(action: onReady) {
                Text("Start")
                    .font(Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
        }
    }

    private func failedView(_ error: BootstrapError) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: AppIcon.warning)
                .font(.system(size: IconSize.lg))
                .foregroundStyle(AppColor.error)
            Text(failureTitle(error))
                .font(Typography.title3)
                .foregroundStyle(AppColor.textPrimary)
            Text(failureMessage(error))
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("Try again")
                    .font(Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
        }
    }

    // MARK: - Behavior

    private func observe() async {
        if await bootstrapper.isReady {
            phase = .ready
            return
        }
        // Kick off the fetch if no one else has — safe to call multiple times
        // because `ModelBootstrapper.fetch()` coalesces concurrent callers.
        fetchTask = Task {
            do {
                try await bootstrapper.fetch()
                phase = .ready
            } catch let error as BootstrapError {
                phase = .failed(error)
            } catch {
                phase = .failed(.network(error.localizedDescription))
            }
        }
        for await update in bootstrapper.progress() {
            progress = update
        }
    }

    private func retry() {
        phase = .waiting
        progress = .idle
        Task { await observe() }
    }

    private var progressSubtitle: String {
        guard progress.bytesTotal > 0 else {
            return "\(Int(progress.fractionCompleted * 100))%"
        }
        let received = ByteCountFormatter.string(fromByteCount: progress.bytesReceived, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: progress.bytesTotal, countStyle: .file)
        return "\(received) / \(total)"
    }

    private func failureTitle(_ error: BootstrapError) -> String {
        switch error {
        case .network: return "Download failed"
        case .diskFull: return "Not enough space"
        case .cancelled: return "Download cancelled"
        case .integrityCheckFailed: return "Download corrupted"
        case .notConfigured: return "Setup incomplete"
        }
    }

    private func failureMessage(_ error: BootstrapError) -> String {
        switch error {
        case .network(let detail): return "Check your connection and try again. (\(detail))"
        case .diskFull: return "Free up some space and try again."
        case .cancelled: return "Tap Try again to resume."
        case .integrityCheckFailed(let reason): return "Please try again. (\(reason))"
        case .notConfigured: return "The model registry is unavailable."
        }
    }
}

#Preview {
    DownloadingAIView(bootstrapper: NullModelBootstrapper(), onReady: {})
}
