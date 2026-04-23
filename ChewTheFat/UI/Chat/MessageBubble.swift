import SwiftUI

@MainActor
struct MessageBubble: View {
    let author: ChatViewModel.DisplayMessage.Author
    let text: String

    var body: some View {
        HStack {
            if author == .user { Spacer(minLength: Spacing.xl) }
            bubble
            if author != .user { Spacer(minLength: Spacing.xl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityPrefix + text))
    }

    private var bubble: some View {
        Text(text)
            .font(Typography.body)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private var background: Color {
        switch author {
        case .user: return AppColor.accent
        case .assistant: return AppColor.surface
        case .system: return AppColor.backgroundSecondary
        }
    }

    private var foreground: Color {
        switch author {
        case .user: return AppColor.backgroundPrimary
        case .assistant, .system: return AppColor.textPrimary
        }
    }

    private var accessibilityPrefix: String {
        switch author {
        case .user: return "You said: "
        case .assistant: return "Coach said: "
        case .system: return "System: "
        }
    }
}

@MainActor
struct TypingIndicator: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(AppColor.textSecondary)
                    .frame(width: Spacing.xs, height: Spacing.xs)
                    .opacity(opacity(for: i))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel(Text("Coach is typing"))
    }

    private func opacity(for index: Int) -> Double {
        if reduceMotion { return 0.6 }
        return index == phase ? 1.0 : 0.3
    }
}
