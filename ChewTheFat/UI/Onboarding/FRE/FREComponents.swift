import SwiftUI

/// Shared transcript atoms for the scripted First Run Experience (FRE).
///
/// The FRE imitates the chat surface — left-aligned question text, right-aligned
/// black pill answers, option-list bubbles — but every user input is a tap or a
/// numeric keypad entry, never free-form text. This lets the user complete
/// profile + goals setup while the MLX model still downloads in the background.
///
/// Each control stays pure presentation: callbacks bubble up to the FRE view
/// model, which owns the scripted flow state.

// MARK: - Title card

@MainActor
struct FRETitleCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColor.surface)
                    .frame(width: Spacing.xxl * 1.5, height: Spacing.xxl * 1.5)
                    .shadow(color: AppColor.border.opacity(0.3), radius: Radius.card)
                Image(systemName: systemImage)
                    .font(.system(size: IconSize.lg))
                    .foregroundStyle(AppColor.textSecondary)
            }
            Text(title)
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}

// MARK: - Question text

@MainActor
struct FREQuestionText: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(Typography.title3)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }
}

// MARK: - Answer pill (right-aligned, black)

@MainActor
struct FREAnswerPill: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: Spacing.xl)
            Text(text)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(AppColor.backgroundPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Your answer: \(text)"))
    }
}

// MARK: - Option list

/// A vertically-stacked list of tappable option rows in a rounded container.
/// Used for preferred units, sex, activity level, weekly change, and ideal
/// weight suggestions.
@MainActor
struct FREOptionList<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    let subtitle: (Option) -> String?
    let onSelect: (Option) -> Void

    init(
        options: [Option],
        title: @escaping (Option) -> String,
        subtitle: @escaping (Option) -> String? = { _ in nil },
        onSelect: @escaping (Option) -> Void
    ) {
        self.options = options
        self.title = title
        self.subtitle = subtitle
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                Button { onSelect(option) } label: {
                    row(for: option)
                }
                .buttonStyle(.plain)
                if index < options.count - 1 {
                    Divider()
                        .background(AppColor.border)
                }
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
        .padding(.horizontal, Spacing.lg)
    }

    private func row(for option: Option) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title(option))
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                if let sub = subtitle(option) {
                    Text(sub)
                        .font(Typography.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: AppIcon.chevronRight)
                .font(.system(size: IconSize.sm))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Numeric entry footer

/// A numeric-keypad-backed text entry bar shown at the bottom of the FRE
/// transcript for age / height / weight questions. Keeps the visual rhythm
/// of a chat composer but binds to a typed field instead of free text.
@MainActor
struct FRENumericEntry: View {
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType
    let onSubmit: () -> Void
    let submitLabel: String
    let canSubmit: Bool

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .stroke(AppColor.border, lineWidth: StrokeWidth.border)
                )
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(triggerSubmit)

            Button(action: triggerSubmit) {
                Text(submitLabel)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(canSubmit ? AppColor.backgroundPrimary : AppColor.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(canSubmit ? AppColor.textPrimary : AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
            }
            .disabled(!canSubmit)
            .accessibilityLabel(Text(submitLabel))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .onAppear { focused = true }
    }

    private func triggerSubmit() {
        guard canSubmit else { return }
        onSubmit()
    }
}

// MARK: - Primary footer button

/// White rounded "Let's go!" / "Yes!" confirm button used at the bottom of
/// summary screens.
@MainActor
struct FREPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(AppColor.border, lineWidth: StrokeWidth.border)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Scripted transcript turn

/// One question + (optional) answer pair. Laid out vertically so the view model
/// can build a transcript by concatenating turns in order.
@MainActor
struct FRETranscriptTurn<Content: View>: View {
    let question: String
    let answer: String?
    @ViewBuilder let control: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FREQuestionText(text: question)
            if let answer {
                FREAnswerPill(text: answer)
            } else {
                control()
            }
        }
        .padding(.bottom, Spacing.md)
    }
}
