import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var author: String
    var textContent: String?

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
        session: Session? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.author = author
        self.textContent = textContent
        self.session = session
    }
}
