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
            environment = try AppEnvironment.live()
        } catch {
            loadError = error
        }
    }
}

private struct RootView: View {
    let environment: AppEnvironment
    @State private var isOnboarded: Bool = false

    var body: some View {
        Group {
            if isOnboarded {
                PlaceholderChatView()
            } else {
                PlaceholderOnboardingView()
            }
        }
        .task { refreshOnboardingState() }
        .environment(\.modelContext, environment.container.mainContext)
    }

    private func refreshOnboardingState() {
        let profile = try? environment.profile.current()
        isOnboarded = profile?.eulaAcceptedAt != nil
    }
}

private struct PlaceholderChatView: View {
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: AppIcon.chat)
                    .font(.system(size: IconSize.lg))
                    .foregroundStyle(AppColor.accent)
                Text("Chat")
                    .font(Typography.title)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Coming in M3")
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
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
