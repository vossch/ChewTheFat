import SwiftUI

/// US7 home screen: Trajectory + Today + quick actions + chat history.
/// Widgets bind live to repositories and refresh on each `ModelChangeTicker`
/// tick, so an edit to a LoggedFood from chat propagates here without an
/// explicit reload.
@MainActor
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    let environment: AppEnvironment
    let onSelectSession: (Session) -> Void
    let onStartNewChat: (SessionGoal) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TrajectoryPanelView(
                    environment: environment,
                    range: viewModel.trajectoryRange,
                    hasAnyWeightHistory: viewModel.hasAnyWeightHistory
                )
                .padding(.horizontal, Spacing.md)

                DashboardNavChipsView { action in
                    onStartNewChat(action.sessionGoal)
                }

                TodayPanelView(
                    environment: environment,
                    date: viewModel.today,
                    meals: viewModel.meals
                )
                .padding(.horizontal, Spacing.md)

                if viewModel.showsChatHistory {
                    ChatHistoryListView(
                        sessions: viewModel.sessions,
                        onSelect: onSelectSession
                    )
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("ChewTheFat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: AppIcon.settings)
                }
                .accessibilityLabel(Text("Settings"))
            }
        }
        .task(id: environment.ticker.tick) { viewModel.reload() }
    }
}
