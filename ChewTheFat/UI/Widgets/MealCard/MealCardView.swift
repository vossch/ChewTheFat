import SwiftUI

@MainActor
struct MealCardView: View {
    @Bindable var viewModel: MealCardViewModel
    let ticker: ModelChangeTicker

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            if viewModel.isEmpty {
                emptyRow
            } else {
                Divider().background(AppColor.border)
                ForEach(viewModel.items) { item in
                    itemRow(item)
                }
                Divider().background(AppColor.border)
                footer
            }
        }
        .padding(Spacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
        .task(id: ticker.tick) { viewModel.reload() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(viewModel.title) \(viewModel.subtitle), \(Int(viewModel.totals.calories.rounded())) calories"))
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: mealIcon)
                .font(.system(size: IconSize.md))
                .foregroundStyle(AppColor.accent)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(viewModel.title.isEmpty ? "Meal" : viewModel.title)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                if !viewModel.subtitle.isEmpty {
                    Text(viewModel.subtitle)
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyRow: some View {
        Text("No foods logged yet.")
            .font(Typography.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.vertical, Spacing.xs)
    }

    private func itemRow(_ item: MealCardViewModel.Item) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Text(item.quantityDescription)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
            Text("\(item.calories) kcal")
                .font(Typography.monoCallout)
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            macroBadge(label: "kcal", value: Int(viewModel.totals.calories.rounded()))
            macroBadge(label: "P", value: Int(viewModel.totals.proteinG.rounded()))
            macroBadge(label: "C", value: Int(viewModel.totals.carbsG.rounded()))
            macroBadge(label: "F", value: Int(viewModel.totals.fatG.rounded()))
            Spacer(minLength: 0)
        }
    }

    private func macroBadge(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(Typography.monoBody)
                .foregroundStyle(AppColor.textPrimary)
            Text(label)
                .font(Typography.caption2)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var mealIcon: String {
        switch viewModel.title.lowercased() {
        case "breakfast": return AppIcon.mealBreakfast
        case "lunch": return AppIcon.mealLunch
        case "dinner": return AppIcon.mealDinner
        case "snack": return AppIcon.mealSnack
        default: return AppIcon.food
        }
    }
}

extension MealCardView {
    /// Chat-emitted widget. Resolves `payload.loggedFoodIds` against the
    /// live store — payloads carry references, not snapshots.
    @MainActor
    static func snapshot(payload: MealCardPayload, environment: AppEnvironment) -> some View {
        let vm = MealCardViewModel(
            mode: .snapshot(ids: payload.loggedFoodIds),
            foodLog: environment.foodLog,
            dateContext: payload.date
        )
        return MealCardView(viewModel: vm, ticker: environment.ticker)
    }

    /// Dashboard widget. Recomputes from the current store on every tick.
    @MainActor
    static func live(meal: MealType, date: Date, environment: AppEnvironment) -> some View {
        let vm = MealCardViewModel(
            mode: .live(meal: meal, date: date),
            foodLog: environment.foodLog,
            dateContext: date
        )
        return MealCardView(viewModel: vm, ticker: environment.ticker)
    }
}
