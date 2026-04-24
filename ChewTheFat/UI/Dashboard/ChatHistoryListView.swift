import SwiftUI

/// Scrollable list of recent chat sessions. Tapping a row jumps the user back
/// into that session. The view is suppressed entirely by the dashboard when
/// no non-onboarding sessions exist (see DashboardViewModel.showsChatHistory).
@MainActor
struct ChatHistoryListView: View {
    let sessions: [Session]
    let onSelect: (Session) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: AppIcon.chat)
                    .font(.system(size: IconSize.md))
                    .foregroundStyle(AppColor.accent)
                Text("Recent chats")
                    .font(Typography.title3)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    Button {
                        onSelect(session)
                    } label: {
                        row(for: session)
                    }
                    .buttonStyle(.plain)
                    if index < sessions.count - 1 {
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
    }

    private func row(for session: Session) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.name)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                Text(relativeDate(session.lastMessageAt))
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: AppIcon.chevronRight)
                .font(.system(size: IconSize.sm))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
