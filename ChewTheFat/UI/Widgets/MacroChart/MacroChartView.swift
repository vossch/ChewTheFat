import SwiftUI
import Charts

@MainActor
struct MacroChartView: View {
    @Bindable var viewModel: MacroChartViewModel
    let ticker: ModelChangeTicker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            chart
            calorieFooter
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
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: AppIcon.chart)
                .font(.system(size: IconSize.md))
                .foregroundStyle(AppColor.accent)
            Text("Macros today")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var chart: some View {
        Chart(viewModel.rows) { row in
            BarMark(
                x: .value("Consumed", row.consumedGrams),
                y: .value("Macro", row.label)
            )
            .foregroundStyle(AppColor.accent)
            .cornerRadius(Radius.chip)
            .annotation(position: .trailing, alignment: .leading, spacing: Spacing.xs) {
                Text(annotation(for: row))
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { _ in
                AxisValueLabel()
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(height: ChartHeight.compact)
        .animation(reduceMotion ? nil : .default, value: viewModel.rows)
        .accessibilityLabel(Text("Macro progress"))
        .accessibilityValue(Text(viewModel.rows.map(accessibilitySummary(for:)).joined(separator: ", ")))
    }

    private var calorieFooter: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: AppIcon.flame)
                .font(.system(size: IconSize.sm))
                .foregroundStyle(AppColor.warning)
            Text("\(viewModel.consumedCalories) / \(viewModel.targetCalories > 0 ? "\(viewModel.targetCalories)" : "—") kcal")
                .font(Typography.monoCallout)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func annotation(for row: MacroChartViewModel.Row) -> String {
        let consumed = Int(row.consumedGrams.rounded())
        if row.targetGrams > 0 {
            return "\(consumed) / \(Int(row.targetGrams.rounded())) g"
        }
        return "\(consumed) g"
    }

    private func accessibilitySummary(for row: MacroChartViewModel.Row) -> String {
        let consumed = Int(row.consumedGrams.rounded())
        if row.targetGrams > 0 {
            return "\(row.label) \(consumed) of \(Int(row.targetGrams.rounded())) grams"
        }
        return "\(row.label) \(consumed) grams"
    }
}

extension MacroChartView {
    @MainActor
    static func live(date: Date, environment: AppEnvironment) -> some View {
        let vm = MacroChartViewModel(date: date, foodLog: environment.foodLog, goals: environment.goals)
        return MacroChartView(viewModel: vm, ticker: environment.ticker)
    }
}
