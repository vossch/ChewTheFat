import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var id: UUID
    var date: Date
    var content: String
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.generatedAt = generatedAt
    }
}
