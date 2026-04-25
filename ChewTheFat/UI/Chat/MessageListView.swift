import SwiftUI

@MainActor
struct MessageListView: View {
    let viewModel: ChatViewModel
    let environment: AppEnvironment

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(viewModel.messages) { message in
                        row(for: message)
                            .id(message.id)
                    }
                    if viewModel.isTyping {
                        HStack {
                            TypingIndicator()
                            Spacer(minLength: Spacing.xl)
                        }
                        .id(typingAnchorId)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isTyping) { _, typing in
                if typing { scrollToBottom(proxy: proxy) }
            }
            .onAppear { scrollToBottom(proxy: proxy, animated: false) }
        }
    }

    @ViewBuilder
    private func row(for message: ChatViewModel.DisplayMessage) -> some View {
        switch message {
        case .text(_, let author, let body):
            MessageBubble(author: author, text: body)
        case .widget(_, let intent):
            HStack {
                WidgetRenderer(
                    intent: intent,
                    environment: environment,
                    onReply: { [weak viewModel] reply in
                        viewModel?.send(reply)
                    }
                )
                Spacer(minLength: 0)
            }
        }
    }

    private var typingAnchorId: String { "typing-anchor" }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = viewModel.isTyping
            ? AnyHashable(typingAnchorId)
            : viewModel.messages.last.map { AnyHashable($0.id) }
        guard let target else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}
