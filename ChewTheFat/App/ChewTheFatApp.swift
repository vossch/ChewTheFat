import SwiftUI
import SwiftData

@main
struct ChewTheFatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment: AppEnvironment?
    @State private var loadError: Error?

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let environment {
            RootView(environment: environment)
        } else if let loadError {
            ContainerErrorView(error: loadError)
        } else {
            ProgressView()
                .task { await loadEnvironment() }
        }
    }

    private func loadEnvironment() async {
        do {
            let env = try AppEnvironment.live()
            environment = env
            Task.detached { await env.warmUpModelIfReady() }
        } catch {
            loadError = error
        }
    }
}

private struct RootView: View {
    let environment: AppEnvironment
    @State private var isOnboarded: Bool = false
    @State private var chatViewModel: ChatViewModel?
    @State private var sessionLoadError: String?

    var body: some View {
        Group {
            if isOnboarded {
                chatRoot
            } else {
                PlaceholderOnboardingView()
            }
        }
        .task { await refreshOnboardingState() }
        .environment(\.modelContext, environment.container.mainContext)
    }

    @ViewBuilder
    private var chatRoot: some View {
        if let chatViewModel {
            ChatView(viewModel: chatViewModel, environment: environment)
        } else if let sessionLoadError {
            ContainerErrorView(error: SimpleError(message: sessionLoadError))
        } else {
            ProgressView()
                .task { await prepareChatSession() }
        }
    }

    private func refreshOnboardingState() async {
        let profile = try? environment.profile.current()
        isOnboarded = profile?.eulaAcceptedAt != nil
    }

    private func prepareChatSession() async {
        do {
            let existing = try environment.sessions.list(limit: 1).first
            let session = try existing ?? environment.sessions.create(goal: .general)
            let orchestrator = environment.makeOrchestrator(for: session)
            chatViewModel = ChatViewModel(orchestrator: orchestrator, session: session)
        } catch {
            sessionLoadError = error.localizedDescription
        }
    }
}

private struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct PlaceholderOnboardingView: View {
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: AppIcon.goals)
                    .font(.system(size: IconSize.lg))
                    .foregroundStyle(AppColor.accent)
                Text("Welcome to ChewTheFat")
                    .font(Typography.title)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Onboarding arrives in M4")
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(Spacing.lg)
        }
    }
}

private struct ContainerErrorView: View {
    let error: Error

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: AppIcon.warning)
                    .font(.system(size: IconSize.lg))
                    .foregroundStyle(AppColor.error)
                Text("Failed to start")
                    .font(Typography.title)
                    .foregroundStyle(AppColor.textPrimary)
                Text(error.localizedDescription)
                    .font(Typography.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.lg)
        }
    }
}
