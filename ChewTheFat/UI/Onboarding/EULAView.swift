import SwiftUI

/// Onboarding phase 1: static legal screen gating the rest of the app.
/// Accepting writes `UserProfile.eulaAcceptedAt`; until then no further UI
/// is reachable (see `OnboardingCoordinator`).
///
/// The copy here is placeholder. Replacing it with real legal text is a doc
/// change — no code changes required.
struct EULAView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                termsScroll
                acceptBar
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: AppIcon.goals)
                .font(.system(size: IconSize.lg))
                .foregroundStyle(AppColor.accent)
            Text("Welcome to ChewTheFat")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)
            Text("Before we begin, please review and accept the terms.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
    }

    private var termsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                section(
                    title: "On-device by design",
                    body: "ChewTheFat runs entirely on this iPhone. Your food logs, weight entries, goals, and chat history stay on your device. We do not send your data to a cloud service."
                )
                section(
                    title: "Optional web lookups",
                    body: "If you turn on the optional web search food fallback in Settings, food names you type may be sent to public food databases solely to find nutrition information. No personal information is sent."
                )
                section(
                    title: "Model weights",
                    body: "On first launch, ChewTheFat downloads the on-device AI model weights from a public registry. Only the model identifier is requested — your data is never sent."
                )
                section(
                    title: "Not medical advice",
                    body: "ChewTheFat is a nutrition tracking and coaching tool, not a substitute for medical or nutritional advice. Consult a qualified professional before making significant changes to your diet."
                )
                section(
                    title: "Placeholder legal copy",
                    body: "This is placeholder copy for development. Final terms of service and privacy policy will replace this text before public release."
                )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(AppColor.border, lineWidth: StrokeWidth.border)
        )
        .padding(.horizontal, Spacing.lg)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(body)
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var acceptBar: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: onAccept) {
                Text("I agree — continue")
                    .font(Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
            .accessibilityLabel("Accept terms and continue")

            Text("You can review these terms later in Settings.")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.lg)
    }
}

#Preview {
    EULAView(onAccept: {})
}
