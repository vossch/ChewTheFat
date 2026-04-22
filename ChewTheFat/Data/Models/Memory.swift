import Foundation
import SwiftData

@Model
final class Memory {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var content: String
    var category: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        content: String,
        category: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.category = category
    }
}
