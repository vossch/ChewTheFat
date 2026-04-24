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
    @State private var onboardingChatViewModel: ChatViewModel?
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
                HomeShellView(environment: environment)
            }
        }
        .task { await coordinator.resolveInitialPhase() }
        .environment(\.modelContext, environment.container.mainContext)
    }

    @ViewBuilder
    private func onboardingChatRoot(session: Session) -> some View {
        let viewModel = onboardingChatVM(for: session)
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

    private func onboardingChatVM(for session: Session) -> ChatViewModel? {
        if let existing = onboardingChatViewModel, existing.session.id == session.id {
            return existing
        }
        let orchestrator = environment.makeOrchestrator(for: session)
        let vm = ChatViewModel(orchestrator: orchestrator, session: session)
        onboardingChatViewModel = vm
        return vm
    }
}

/// Post-onboarding shell. Dashboard is the landing screen (US7) and pushes
/// Chat / Settings via a NavigationStack. Each chat session gets its own
/// `ChatViewModel` so switching sessions doesn't leak state.
private struct HomeShellView: View {
    let environment: AppEnvironment
    @State private var dashboardVM: DashboardViewModel
    @State private var path: [Route] = []
    @State private var chatViewModels: [UUID: ChatViewModel] = [:]
    @State private var loadError: String?

    enum Route: Hashable {
        case chat(sessionId: UUID)
        case settings
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        _dashboardVM = State(initialValue: DashboardViewModel(
            sessions: environment.sessions,
            weightLog: environment.weightLog
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            DashboardView(
                viewModel: dashboardVM,
                environment: environment,
                onSelectSession: { session in
                    path.append(.chat(sessionId: session.id))
                },
                onStartNewChat: { goal in
                    guard let session = createSession(goal: goal) else { return }
                    path.append(.chat(sessionId: session.id))
                },
                onOpenSettings: {
                    path.append(.settings)
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .chat(let id):
                    chatRoute(for: id)
                case .settings:
                    SettingsView(environment: environment, preferences: environment.preferences)
                }
            }
        }
    }

    @ViewBuilder
    private func chatRoute(for sessionId: UUID) -> some View {
        if let vm = chatViewModel(for: sessionId) {
            ChatView(viewModel: vm, environment: environment)
        } else if let loadError {
            ContainerErrorView(error: SimpleError(message: loadError))
        } else {
            ProgressView()
        }
    }

    private func chatViewModel(for id: UUID) -> ChatViewModel? {
        if let existing = chatViewModels[id] { return existing }
        do {
            guard let session = try environment.sessions.find(id: id) else { return nil }
            let orchestrator = environment.makeOrchestrator(for: session)
            let vm = ChatViewModel(orchestrator: orchestrator, session: session)
            chatViewModels[id] = vm
            return vm
        } catch {
            loadError = error.localizedDescription
            return nil
        }
    }

    private func createSession(goal: SessionGoal) -> Session? {
        do {
            return try environment.sessions.create(goal: goal)
        } catch {
            loadError = error.localizedDescription
            return nil
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
