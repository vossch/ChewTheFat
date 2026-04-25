import SwiftUI

@MainActor
struct WeightLogPromptView: View {
    @Bindable var viewModel: WeightLogPromptViewModel
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .center, spacing: Spacing.lg) {
            titleCard
            if !viewModel.isCollapsed {
                optionsList
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var titleCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: AppIcon.weighIn)
                .font(.system(size: IconSize.lg * 2, weight: .regular))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(viewModel.title)
                    .font(Typography.title2.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(viewModel.subtitle)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var optionsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.options) { option in
                Button {
                    let reply = viewModel.replyText(for: option)
                    viewModel.markCollapsed()
                    onPick(reply)
                } label: {
                    row(option)
                }
                .buttonStyle(.plain)
                if option.id != viewModel.options.last?.id {
                    Divider().background(AppColor.border)
                }
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
    }

    private func row(_ option: WeightLogPromptViewModel.Option) -> some View {
        HStack {
            Text(option.label)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(option.label))
    }
}
