import SwiftUI

@MainActor
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    let environment: AppEnvironment
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, environment: environment)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SuggestedRepliesView(suggestions: []) { suggestion in
                draft = suggestion
            }

            ChatInputBar(
                text: $draft,
                isBusy: viewModel.status == .sending || viewModel.status == .streaming,
                onSend: {
                    let toSend = draft
                    draft = ""
                    viewModel.send(toSend)
                }
            )

            if case .error(let message) = viewModel.status {
                errorBanner(message)
            }
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.primeIfNeeded() }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: AppIcon.warning)
                .foregroundStyle(AppColor.error)
            Text(message)
                .font(Typography.footnote)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .transition(.opacity)
    }
}
