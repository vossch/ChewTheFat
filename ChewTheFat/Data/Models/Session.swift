import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var lastMessageAt: Date
    var context: String?
    var goal: String

    @Relationship(deleteRule: .cascade, inverse: \Message.session)
    var messages: [Message] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        lastMessageAt: Date = .now,
        context: String? = nil,
        goal: String
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.context = context
        self.goal = goal
    }
}
