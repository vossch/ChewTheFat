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
    @State private var coordinator: OnboardingCoordinator
    @State private var chatViewModel: ChatViewModel?
    @State private var sessionLoadError: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        _coordinator = State(initialValue: OnboardingCoordinator(
            profile: environment.profile,
            sessions: environment.sessions,
            evaluator: environment.goalEvaluator,
            bootstrapper: environment.modelBootstrapper
        ))
    }

    var body: some View {
        Group {
            switch coordinator.phase {
            case .loading:
                ProgressView()
            case .eula:
                EULAView(onAccept: coordinator.acceptEULA)
            case .bootstrap:
                ModelBootstrapView(
                    bootstrapper: environment.modelBootstrapper,
                    onComplete: coordinator.bootstrapDidComplete
                )
            case .chat(let session):
                onboardingChatRoot(session: session)
            case .ready:
                readyChatRoot
            }
        }
        .task { await coordinator.resolveInitialPhase() }
        .environment(\.modelContext, environment.container.mainContext)
    }

    @ViewBuilder
    private func onboardingChatRoot(session: Session) -> some View {
        let viewModel = chatViewModel(for: session)
        if let viewModel {
            ChatView(viewModel: viewModel, environment: environment)
                .task(id: environment.ticker.tick) {
                    await coordinator.recheckOnboardingCompletion()
                }
        } else if let sessionLoadError {
            ContainerErrorView(error: SimpleError(message: sessionLoadError))
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var readyChatRoot: some View {
        if let chatViewModel {
            ChatView(viewModel: chatViewModel, environment: environment)
        } else if let sessionLoadError {
            ContainerErrorView(error: SimpleError(message: sessionLoadError))
        } else {
            ProgressView()
                .task { await prepareReadyChatSession() }
        }
    }

    private func chatViewModel(for session: Session) -> ChatViewModel? {
        if let existing = chatViewModel, existing.session.id == session.id {
            return existing
        }
        let orchestrator = environment.makeOrchestrator(for: session)
        let vm = ChatViewModel(orchestrator: orchestrator, session: session)
        chatViewModel = vm
        return vm
    }

    private func prepareReadyChatSession() async {
        do {
            let nonOnboarding = try environment.sessions.list(limit: 20)
                .first { $0.goal != SessionGoal.onboarding.rawValue }
            let session = try nonOnboarding ?? environment.sessions.create(goal: .general)
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
