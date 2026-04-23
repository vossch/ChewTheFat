import SwiftUI

/// Renders model-authored quick replies as tap-through chips. Intentionally
/// a data-driven shell — static fallbacks are not used (they're worse than
/// nothing). Real suggestions arrive from the orchestrator starting in M7.
@MainActor
struct SuggestedRepliesView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { onSelect(suggestion) }) {
                            Text(suggestion)
                                .font(Typography.footnote)
                                .foregroundStyle(AppColor.textPrimary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.pill)
                                        .stroke(AppColor.border, lineWidth: StrokeWidth.border)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Suggested reply: \(suggestion)"))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
    }
}
