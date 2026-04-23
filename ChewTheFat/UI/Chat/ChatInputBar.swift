import SwiftUI

@MainActor
struct ChatInputBar: View {
    @Binding var text: String
    let isBusy: Bool
    let onSend: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            disabledIconButton(systemName: AppIcon.mic, label: "Voice input (coming soon)")
            disabledIconButton(systemName: AppIcon.camera, label: "Camera (coming soon)")
            textField
            sendButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.backgroundSecondary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.border)
                .frame(height: StrokeWidth.hairline)
        }
    }

    private var textField: some View {
        TextField("Message", text: $text, axis: .vertical)
            .font(Typography.body)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1...5)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(AppColor.border, lineWidth: StrokeWidth.border)
            )
            .focused($focused)
            .submitLabel(.send)
            .onSubmit(triggerSend)
            .accessibilityLabel(Text("Message"))
    }

    private var sendButton: some View {
        Button(action: triggerSend) {
            Image(systemName: AppIcon.send)
                .font(.system(size: IconSize.md))
                .foregroundStyle(canSend ? AppColor.accent : AppColor.textSecondary)
                .padding(Spacing.sm)
        }
        .disabled(!canSend)
        .accessibilityLabel(Text("Send message"))
    }

    private func disabledIconButton(systemName: String, label: String) -> some View {
        // Mic + camera are placeholders per FR-022 (voice/camera deferred post-v1).
        Image(systemName: systemName)
            .font(.system(size: IconSize.md))
            .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            .padding(Spacing.sm)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Disabled"))
    }

    private var canSend: Bool {
        !isBusy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerSend() {
        guard canSend else { return }
        onSend()
    }
}
