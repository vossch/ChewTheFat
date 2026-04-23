import SwiftUI
import Charts

@MainActor
struct WeightGraphView: View {
    @Bindable var viewModel: WeightGraphViewModel
    let ticker: ModelChangeTicker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            chart
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
            Image(systemName: AppIcon.weight)
                .font(.system(size: IconSize.md))
                .foregroundStyle(AppColor.accent)
            Text("Weight trajectory")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
    }

    @ChartContentBuilder
    private var pastContent: some ChartContent {
        ForEach(viewModel.points.filter { !$0.isProjected }) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weightKg),
                series: .value("Segment", "past")
            )
            .foregroundStyle(AppColor.accent)
            .interpolationMethod(.monotone)
            .symbol(Circle())
            .symbolSize(36)
        }
    }

    @ChartContentBuilder
    private var projectedContent: some ChartContent {
        ForEach(viewModel.points.filter(\.isProjected)) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weightKg),
                series: .value("Segment", "projected")
            )
            .foregroundStyle(AppColor.accent.opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: StrokeWidth.emphasis, dash: DashPattern.projected))
            .interpolationMethod(.monotone)
        }
    }

    @ChartContentBuilder
    private var idealRule: some ChartContent {
        if let ideal = viewModel.idealWeightKg {
            RuleMark(y: .value("Goal", ideal))
                .foregroundStyle(AppColor.success.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: StrokeWidth.border, dash: DashPattern.goal))
                .annotation(position: .topTrailing, alignment: .trailing) {
                    Text("Goal \(Int(ideal.rounded())) kg")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
        }
    }

    private var chart: some View {
        Chart {
            pastContent
            projectedContent
            idealRule
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColor.border)
                AxisValueLabel()
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColor.border)
                AxisValueLabel()
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(height: ChartHeight.standard)
        .animation(reduceMotion ? nil : .default, value: viewModel.points)
        .accessibilityLabel(Text("Weight trajectory"))
    }
}

extension WeightGraphView {
    @MainActor
    static func live(range: ClosedRange<Date>, environment: AppEnvironment) -> some View {
        let vm = WeightGraphViewModel(
            range: range,
            weightLog: environment.weightLog,
            goals: environment.goals
        )
        return WeightGraphView(viewModel: vm, ticker: environment.ticker)
    }
}
