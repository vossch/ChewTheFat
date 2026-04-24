import SwiftUI

/// Goals editor (US6, FR-023). Auto mode derives calories; Manual mode lets
/// the user set the calorie target directly and drag three percentage sliders
/// whose sum always stays at exactly 100 (see `GoalsEditViewModel.adjust`).
@MainActor
struct GoalsEditView: View {
    @Bindable var viewModel: GoalsEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Method") {
                Picker("Method", selection: $viewModel.method) {
                    ForEach(GoalsEditViewModel.Method.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Weight") {
                TextField(
                    "Ideal weight (\(UnitFormatter.weightUnitLabel(viewModel.preferredUnits)))",
                    text: $viewModel.idealWeightInput
                )
                .keyboardType(.decimalPad)

                weeklyChangeRow
            }

            Section(header: Text("Calories"), footer: caloriesFooter) {
                if viewModel.method == .manual {
                    Stepper(
                        value: $viewModel.calorieTarget,
                        in: 800...5000,
                        step: 25
                    ) {
                        Text("\(viewModel.calorieTarget) kcal")
                            .font(Typography.monoBody)
                    }
                } else {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(viewModel.calorieTarget) kcal")
                            .font(Typography.monoBody)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }

            Section(
                header: Text("Macros"),
                footer: macroSumFooter
            ) {
                macroSlider("Protein", percent: viewModel.proteinPct) { new in
                    viewModel.adjust(.protein, to: new)
                }
                .disabled(viewModel.method == .auto)
                macroSlider("Carbs", percent: viewModel.carbsPct) { new in
                    viewModel.adjust(.carbs, to: new)
                }
                .disabled(viewModel.method == .auto)
                macroSlider("Fat", percent: viewModel.fatPct) { new in
                    viewModel.adjust(.fat, to: new)
                }
                .disabled(viewModel.method == .auto)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: AppIcon.warning)
                        .foregroundStyle(AppColor.error)
                }
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if viewModel.save() { dismiss() }
                }
            }
        }
        .task { viewModel.load() }
    }

    private var weeklyChangeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Weekly change")
                Spacer()
                Text(String(format: "%+.2f kg/wk", viewModel.weeklyChangeKg))
                    .font(Typography.monoBody)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Slider(
                value: $viewModel.weeklyChangeKg,
                in: -0.7...0.45,
                step: 0.05
            )
        }
    }

    private var caloriesFooter: some View {
        Text(viewModel.method == .auto
             ? "Derived from your profile and weekly change."
             : "Type a custom target — macros re-derive from your percentages.")
            .font(Typography.caption)
            .foregroundStyle(AppColor.textSecondary)
    }

    private var macroSumFooter: some View {
        let total = Int((viewModel.proteinPct + viewModel.carbsPct + viewModel.fatPct).rounded())
        return Text("Total: \(total)%")
            .font(Typography.caption)
            .foregroundStyle(total == 100 ? AppColor.textSecondary : AppColor.warning)
    }

    private func macroSlider(
        _ label: String,
        percent: Double,
        onChange: @escaping @MainActor (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .font(Typography.monoBody)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { percent },
                    set: onChange
                ),
                in: 0...100,
                step: 1
            )
        }
    }
}
