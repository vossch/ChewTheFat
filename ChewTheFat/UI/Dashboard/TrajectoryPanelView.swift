import SwiftUI

/// Trajectory panel — a live WeightGraphView bound to the last 90 days. Falls
/// back to a prompt when no WeightEntry rows exist yet (spec §US7 edge case).
@MainActor
struct TrajectoryPanelView: View {
    let environment: AppEnvironment
    let range: ClosedRange<Date>
    let hasAnyWeightHistory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Trajectory", systemImage: AppIcon.weight)
            if hasAnyWeightHistory {
                WeightGraphView.live(range: range, environment: environment)
            } else {
                emptyState
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: IconSize.md))
                .foregroundStyle(AppColor.accent)
            Text(title)
                .font(Typography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("No weight history yet.")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("Log your first weight in chat and it will appear here.")
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
    }
}
