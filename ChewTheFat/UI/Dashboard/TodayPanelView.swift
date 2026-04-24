import SwiftUI

/// "Today" panel on the dashboard. Macro progress across all logs for the
/// current day plus a summary meal list. Widgets bind live via repositories
/// — this panel does not cache payloads.
@MainActor
struct TodayPanelView: View {
    let environment: AppEnvironment
    let date: Date
    let meals: [MealType]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Today", systemImage: AppIcon.chart)
            MacroChartView.live(date: date, environment: environment)
            ForEach(meals, id: \.self) { meal in
                MealCardView.live(meal: meal, date: date, environment: environment)
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
}
