import Foundation

/// Heuristic-only post-turn memory recorder. Inspects each completed turn
/// for two kinds of signal:
///
/// 1. Significant tool calls — `set_goals`, `set_profile_info`, and
///    `log_weight` calls that were flagged as anomalous by the coaching
///    heuristic. Routine meal logs are deliberately *not* recorded; they
///    would drown the recent-memory window in noise.
/// 2. Explicit user-authored cues — anything starting with "remember that",
///    "note that", or "fyi" is captured verbatim.
///
/// No model-gated summarisation in v1 (deferred per M7 plan); the future
/// `MemoryTrigger` can layer on top of this as a second pass.
@MainActor
struct MemoryWriter {
    let memory: MemoryRepository

    func observe(
        userText: String?,
        toolOutcomes: [ToolCallOutcome]
    ) {
        if let userText, let extracted = Self.explicitMemoryCue(in: userText) {
            try? memory.add(content: extracted, category: "userNote")
        }
        for outcome in toolOutcomes {
            guard case .success(let call, let result) = outcome else { continue }
            guard let entry = Self.entry(for: call, result: result) else { continue }
            try? memory.add(content: entry.content, category: entry.category)
        }
    }

    private struct Entry { let content: String; let category: String }

    private static func entry(
        for call: ToolCallRequest,
        result: ToolResult
    ) -> Entry? {
        switch call.identifier {
        case .setProfileInfo:
            return Entry(
                content: "User updated their profile.",
                category: "userProfile"
            )
        case .setGoals:
            return Entry(
                content: "User updated their goals.",
                category: "userGoals"
            )
        case .logWeight:
            guard let json = try? JSONSerialization.jsonObject(with: result.payload) as? [String: Any],
                  let flag = json["coachingFlag"] as? String,
                  flag != CoachingFlag.normal.rawValue,
                  let weight = json["weightKg"] as? Double
            else { return nil }
            let formatted = String(format: "%.1f", weight)
            return Entry(
                content: "Weigh-in flagged \(flag) at \(formatted) kg.",
                category: "weightFlag"
            )
        default:
            return nil
        }
    }

    private static let cuePrefixes: [String] = [
        "remember that ", "remember this:", "note that ", "note this:", "fyi "
    ]

    static func explicitMemoryCue(in text: String) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in cuePrefixes where lower.hasPrefix(prefix) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? nil : body
        }
        return nil
    }
}
