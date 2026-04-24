import SwiftUI

/// Scripted goal-setup chat surface. Chains weekly change preset → activity →
/// current weight → ideal weight → summary. Final CTA hands off to the model
/// download waiting screen (or straight to Ready, if weights landed during
/// setup).
@MainActor
struct GoalsFREView: View {
    @Bindable var viewModel: GoalsFREViewModel
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.backgroundPrimary.ignoresSafeArea()
            transcript
            if let error = viewModel.errorMessage {
                errorBanner(error)
                    .padding(.bottom, Spacing.md)
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    FRETitleCard(
                        systemImage: AppIcon.target,
                        title: "OK, let's set your goals",
                        subtitle: "A few quick choices and we'll suggest daily calorie and macro targets."
                    )
                    ForEach(viewModel.turns) { turn in
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            FREQuestionText(text: turn.question)
                            if let answer = turn.answer {
                                FREAnswerPill(text: answer)
                            } else {
                                inlineControl(for: turn.id)
                            }
                        }
                        .id(turn.id)
                    }
                    if viewModel.step == .summary {
                        summaryCard
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)
                            .id(GoalsFREViewModel.Step.summary)
                    }
                    Color.clear.frame(height: Spacing.xxl)
                }
            }
            .onChange(of: viewModel.step) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func inlineControl(for step: GoalsFREViewModel.Step) -> some View {
        switch step {
        case .weeklyChange:
            FREOptionList(
                options: GoalsFREViewModel.weeklyChangeOptions,
                title: \.title,
                subtitle: { $0.subtitle },
                onSelect: { viewModel.selectWeeklyChange($0) }
            )
        case .activity:
            FREOptionList(
                options: GoalsFREViewModel.activityOptions.map(ActivityOption.init),
                title: \.label,
                subtitle: { $0.sub },
                onSelect: { viewModel.selectActivity($0.value) }
            )
        case .idealWeight:
            idealWeightSuggestions
        default:
            EmptyView()
        }
    }

    private var idealWeightSuggestions: some View {
        let suggestions = viewModel.idealWeightSuggestions.map { suggestion in
            IdealOption(
                value: suggestion,
                unit: viewModel.preferredUnitSystem
            )
        }
        return FREOptionList(
            options: suggestions,
            title: \.label,
            subtitle: { $0.sub },
            onSelect: { viewModel.selectIdealWeight($0.value) }
        )
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch viewModel.step {
        case .currentWeight:
            FRENumericEntry(
                text: $viewModel.currentWeightInput,
                placeholder: "Weight in \(viewModel.weightUnitLabel)",
                keyboard: .decimalPad,
                onSubmit: viewModel.submitCurrentWeight,
                submitLabel: "Next",
                canSubmit: !viewModel.currentWeightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .background(AppColor.backgroundPrimary)
        case .idealWeight:
            FRENumericEntry(
                text: $viewModel.idealWeightInput,
                placeholder: "Or type a goal in \(viewModel.weightUnitLabel)",
                keyboard: .decimalPad,
                onSubmit: viewModel.submitCustomIdealWeight,
                submitLabel: "Next",
                canSubmit: !viewModel.idealWeightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .background(AppColor.backgroundPrimary)
        case .summary:
            HStack(spacing: Spacing.sm) {
                Spacer(minLength: 0)
                FREPrimaryButton(title: "Yes!") {
                    if viewModel.commitSummary() { onContinue() }
                }
            }
            .padding(.vertical, Spacing.sm)
            .background(AppColor.backgroundPrimary)
        default:
            EmptyView()
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("This is what I've captured:")
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            choicesCard
            caloriesCard
            Text("Ready to start logging?")
                .font(Typography.title3)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, Spacing.sm)
        }
    }

    private var choicesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Daily targets")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
                Picker("", selection: $viewModel.method) {
                    ForEach(GoalsFREViewModel.Method.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
            .padding(Spacing.md)
            Divider().background(AppColor.border)
            HStack {
                Text("Weekly change")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
                Text(viewModel.weeklyChange?.title ?? "—")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.accent)
            }
            .padding(Spacing.md)
            Divider().background(AppColor.border)
            HStack {
                Text("Activity level")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
                Text(viewModel.activity?.displayName ?? "—")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.accent)
            }
            .padding(Spacing.md)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
    }

    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(viewModel.summaryCalories.formatted())")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Calories")
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                    Text("per day")
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            if viewModel.method == .manual {
                manualCaloriesEditor
                macroSliders
            }
            HStack(alignment: .top, spacing: Spacing.md) {
                macroPill(title: "Protein", grams: viewModel.summaryMacros.proteinG)
                macroPill(title: "Carbs", grams: viewModel.summaryMacros.carbsG)
                macroPill(title: "Fat", grams: viewModel.summaryMacros.fatG)
                Spacer(minLength: 0)
            }
            Divider().background(AppColor.border)
            goalDateRow
        }
        .padding(Spacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
    }

    private func macroPill(title: String, grams: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(Int(grams.rounded()))g")
                .font(Typography.title3)
                .foregroundStyle(AppColor.accent)
            Text(title)
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var manualCaloriesEditor: some View {
        HStack {
            Text("Calories")
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
            Spacer(minLength: 0)
            Stepper(
                value: $viewModel.manualCalories,
                in: 1000...5000,
                step: 50
            ) {
                Text("\(viewModel.manualCalories) kcal")
                    .font(Typography.monoCallout)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
    }

    private var macroSliders: some View {
        VStack(spacing: Spacing.sm) {
            macroSlider(
                label: "Protein",
                value: viewModel.proteinPct,
                onChange: { viewModel.adjustMacro(.protein, to: $0) }
            )
            macroSlider(
                label: "Carbs",
                value: viewModel.carbsPct,
                onChange: { viewModel.adjustMacro(.carbs, to: $0) }
            )
            macroSlider(
                label: "Fat",
                value: viewModel.fatPct,
                onChange: { viewModel.adjustMacro(.fat, to: $0) }
            )
        }
    }

    private func macroSlider(
        label: String,
        value: Double,
        onChange: @escaping @MainActor (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label)
                    .font(Typography.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer(minLength: 0)
                Text("\(Int(value.rounded()))%")
                    .font(Typography.monoCallout)
                    .foregroundStyle(AppColor.textPrimary)
            }
            Slider(
                value: Binding(get: { value }, set: { onChange($0) }),
                in: 0...100,
                step: 1
            )
            .tint(AppColor.accent)
        }
    }

    private var goalDateRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .foregroundStyle(AppColor.textSecondary)
            if let date = viewModel.projectedGoalDate {
                Text("Goal: \(date.formatted(date: .long, time: .omitted))")
                    .font(Typography.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                Text("No projected goal date")
                    .font(Typography.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: AppIcon.warning)
                .foregroundStyle(AppColor.error)
            Text(message)
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .padding(.horizontal, Spacing.lg)
    }
}

private struct ActivityOption: Identifiable, Hashable {
    let value: ActivityLevel
    var id: String { value.rawValue }
    var label: String { value.displayName }
    var sub: String? { value.subtitle }
}

private struct IdealOption: Identifiable, Hashable {
    let value: GoalsFREViewModel.IdealWeightSuggestion
    let unit: PreferredUnitSystem
    var id: String { value.id }
    var label: String {
        let display = UnitFormatter.weightValue(kg: value.kg, in: unit)
        return "\(Int(display.rounded()))"
    }
    var sub: String? { value.label }
}
