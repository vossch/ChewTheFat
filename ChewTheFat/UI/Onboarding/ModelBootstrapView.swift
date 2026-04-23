import SwiftUI

/// Onboarding phase 2 (see implementation-plan.md M4): runs the first-launch
/// model fetch and surfaces progress, errors, and a retry affordance.
///
/// Invokes `onComplete()` once weights are on disk. The caller (onboarding
/// coordinator) advances to the conversational phase on completion.
struct ModelBootstrapView: View {
    let bootstrapper: ModelBootstrapperProtocol
    let onComplete: () -> Void

    @State private var phase: Phase = .checking
    @State private var fetchTask: Task<Void, Never>?

    enum Phase: Equatable {
        case checking
        case fetching(BootstrapProgress)
        case complete
        case failed(BootstrapError)
    }

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            content
                .padding(Spacing.lg)
        }
        .task { await bootstrapIfNeeded() }
        .onDisappear { fetchTask?.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .checking:
            checkingView
        case .fetching(let progress):
            fetchingView(progress)
        case .complete:
            completeView
        case .failed(let error):
            failedView(error)
        }
    }

    // MARK: - Phase views

    private var checkingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("Preparing…")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func fetchingView(_ progress: BootstrapProgress) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: IconSize.lg))
                .foregroundStyle(AppColor.accent)
            Text("Downloading model")
                .font(Typography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("This happens once. Weights stay on your device.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            ProgressView(value: progress.fractionCompleted)
                .progressViewStyle(.linear)
                .tint(AppColor.accent)
                .accessibilityLabel("Download progress")
                .accessibilityValue("\(Int(progress.fractionCompleted * 100)) percent")

            Text(progressSubtitle(progress))
                .font(Typography.monoCallout)
                .foregroundStyle(AppColor.textSecondary)

            Button(role: .cancel) {
                Task {
                    fetchTask?.cancel()
                    await bootstrapper.cancel()
                }
            } label: {
                Text("Cancel")
                    .font(Typography.bodyEmphasized)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private var completeView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: AppIcon.check)
                .font(.system(size: IconSize.lg))
                .foregroundStyle(AppColor.success)
            Text("Model ready")
                .font(Typography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Button(action: onComplete) {
                Text("Continue")
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

    private func bootstrapIfNeeded() async {
        if await bootstrapper.isReady {
            phase = .complete
            return
        }
        phase = .fetching(.idle)
        fetchTask = Task {
            do {
                try await bootstrapper.fetch()
                phase = .complete
            } catch let error as BootstrapError {
                phase = .failed(error)
            } catch {
                phase = .failed(.network(error.localizedDescription))
            }
        }
        for await progress in bootstrapper.progress() {
            if case .fetching = phase {
                phase = .fetching(progress)
            }
        }
    }

    private func retry() {
        phase = .checking
        Task { await bootstrapIfNeeded() }
    }

    private func progressSubtitle(_ p: BootstrapProgress) -> String {
        guard p.bytesTotal > 0 else {
            return "\(Int(p.fractionCompleted * 100))%"
        }
        let received = ByteCountFormatter.string(fromByteCount: p.bytesReceived, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: p.bytesTotal, countStyle: .file)
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
        case .network(let detail):
            return "Check your connection and try again. (\(detail))"
        case .diskFull:
            return "Free up some space and try again."
        case .cancelled:
            return "Tap Try again to resume."
        case .integrityCheckFailed(let reason):
            return "Please try again. (\(reason))"
        case .notConfigured:
            return "The model registry is unavailable."
        }
    }
}

#Preview("Idle") {
    ModelBootstrapView(bootstrapper: NullModelBootstrapper(), onComplete: {})
}
