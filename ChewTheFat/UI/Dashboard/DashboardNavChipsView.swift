import SwiftUI

/// Quick-action chips under the Today panel — jumping the user back to chat
/// with an intent hint. Chat history is the natural surface for opening a
/// previous session, so these focus on starting a *new* chat with context.
@MainActor
struct DashboardNavChipsView: View {
    enum Action: Identifiable, Hashable {
        case logMeal
        case logWeight
        case insights
        case newChat

        var id: Self { self }

        var title: String {
            switch self {
            case .logMeal: return "Log a meal"
            case .logWeight: return "Log weight"
            case .insights: return "Insights"
            case .newChat: return "New chat"
            }
        }

        var systemImage: String {
            switch self {
            case .logMeal: return AppIcon.food
            case .logWeight: return AppIcon.weight
            case .insights: return AppIcon.chart
            case .newChat: return AppIcon.chat
            }
        }

        var sessionGoal: SessionGoal {
            switch self {
            case .logMeal: return .logMeal
            case .logWeight: return .logWeight
            case .insights: return .userInsights
            case .newChat: return .general
            }
        }
    }

    let onSelect: (Action) -> Void

    private let items: [Action] = [.logMeal, .logWeight, .insights, .newChat]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        chipLabel(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.title))
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func chipLabel(_ item: Action) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: item.systemImage)
                .font(.system(size: IconSize.sm))
            Text(item.title)
                .font(Typography.callout)
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
    }
}
