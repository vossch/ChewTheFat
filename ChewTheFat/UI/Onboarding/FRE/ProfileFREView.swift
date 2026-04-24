import SwiftUI

/// Scripted profile-setup chat surface. Mirrors the FRE Profile Setup Figma
/// screens: title card + chained question/answer turns, each answered via a
/// tap-list or numeric keypad. Ends with a summary card + "Let's go!" CTA
/// that hands off to the Goals FRE.
@MainActor
struct ProfileFREView: View {
    @Bindable var viewModel: ProfileFREViewModel
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
                        systemImage: AppIcon.profile,
                        title: "Let's set up your profile",
                        subtitle: "We'll need basic profile details to calculate goals (units, sex, age, and height)."
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
                            .id(ProfileFREViewModel.Step.summary)
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
    private func inlineControl(for step: ProfileFREViewModel.Step) -> some View {
        switch step {
        case .units:
            FREOptionList(
                options: PreferredUnitSystem.allCases.map(UnitOption.init),
                title: \.label,
                subtitle: { _ in nil },
                onSelect: { viewModel.selectUnits($0.value) }
            )
        case .sex:
            FREOptionList(
                options: BiologicalSex.allCases.map(SexOption.init),
                title: \.label,
                subtitle: { _ in nil },
                onSelect: { viewModel.selectSex($0.value) }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch viewModel.step {
        case .age:
            FRENumericEntry(
                text: $viewModel.ageInput,
                placeholder: "Type",
                keyboard: .numberPad,
                onSubmit: viewModel.submitAge,
                submitLabel: "Next",
                canSubmit: !viewModel.ageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .background(AppColor.backgroundPrimary)
        case .height:
            FRENumericEntry(
                text: $viewModel.heightInput,
                placeholder: heightPlaceholder,
                keyboard: viewModel.units == .imperial ? .numbersAndPunctuation : .decimalPad,
                onSubmit: viewModel.submitHeight,
                submitLabel: "Next",
                canSubmit: !viewModel.heightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .background(AppColor.backgroundPrimary)
        case .summary:
            HStack(spacing: Spacing.sm) {
                Spacer(minLength: 0)
                FREPrimaryButton(title: "Let's go!") {
                    if viewModel.commitSummary() { onContinue() }
                }
            }
            .padding(.vertical, Spacing.sm)
            .background(AppColor.backgroundPrimary)
        default:
            EmptyView()
        }
    }

    private var heightPlaceholder: String {
        switch viewModel.units {
        case .imperial: return "5-11 or 5'11\""
        case .metric: return "180 cm"
        case .none: return "Type"
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Great. We'll use this information to help set reasonable targets.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            VStack(spacing: 0) {
                summaryRow(label: "Birth year", value: viewModel.birthYear.map(String.init) ?? "—")
                Divider().background(AppColor.border)
                heightSummaryRow
                Divider().background(AppColor.border)
                sexToggleRow
            }
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(AppColor.border, lineWidth: StrokeWidth.border)
            )
            Text("Ready to set goals?")
                .font(Typography.title3)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, Spacing.sm)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
            Text(value)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(Spacing.md)
    }

    @ViewBuilder
    private var heightSummaryRow: some View {
        HStack {
            Text("Height")
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
            if let ft = viewModel.heightFeetInches {
                HStack(spacing: Spacing.xs) {
                    Text("\(ft.feet)")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("ft")
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                    Text("\(ft.inches)")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("in")
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            } else {
                Text("—")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .padding(Spacing.md)
    }

    private var sexToggleRow: some View {
        HStack {
            Text("Sex")
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
            Picker("Sex", selection: Binding(
                get: { viewModel.sex ?? .male },
                set: { viewModel.toggleSummarySex($0) }
            )) {
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.displayName).tag(sex)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
        .padding(Spacing.md)
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

// Tiny wrappers so option lists satisfy `Identifiable & Hashable` without
// requiring the underlying enums to do so themselves.
private struct UnitOption: Identifiable, Hashable {
    let value: PreferredUnitSystem
    var id: String { value.rawValue }
    var label: String { value.displayName }
}

private struct SexOption: Identifiable, Hashable {
    let value: BiologicalSex
    var id: String { value.rawValue }
    var label: String { value.displayName }
}
