import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var author: String
    var textContent: String?
    /// Optional JSON-encoded `[String]` of quick-reply suggestions stamped on
    /// the assistant message at the moment it was authored. Populated by the
    /// `SessionTrigger`-driven seeding flow so the meal-prompt chips survive
    /// app relaunch; cleared once the user replies (M7).
    var suggestionsJSON: Data?

    var session: Session?

    @Relationship(deleteRule: .cascade, inverse: \MessageWidget.message)
    var widgets: [MessageWidget] = []

    var loggedFood: LoggedFood?
    var weightEntry: WeightEntry?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        author: String,
        textContent: String? = nil,
        suggestionsJSON: Data? = nil,
        session: Session? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.author = author
        self.textContent = textContent
        self.suggestionsJSON = suggestionsJSON
        self.session = session
    }
}

extension Message {
    /// Convenience: stored suggestions decoded back into Swift strings.
    /// Returns `[]` when none were stamped or decoding fails.
    var suggestions: [String] {
        guard let data = suggestionsJSON,
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }
}
