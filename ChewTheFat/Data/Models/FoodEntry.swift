import Foundation
import SwiftData

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String?
    var source: String
    var sourceRefId: String?
    var createdAt: Date
    var lastLoggedAt: Date
    var logCount: Int
    var searchTokens: String

    @Relationship(deleteRule: .cascade, inverse: \Serving.foodEntry)
    var servings: [Serving] = []

    @Relationship(deleteRule: .cascade, inverse: \LoggedFood.foodEntry)
    var loggedFoods: [LoggedFood] = []

    init(
        id: UUID = UUID(),
        name: String,
        detail: String? = nil,
        source: String,
        sourceRefId: String? = nil,
        createdAt: Date = .now,
        lastLoggedAt: Date = .now,
        logCount: Int = 0,
        searchTokens: String
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.source = source
        self.sourceRefId = sourceRefId
        self.createdAt = createdAt
        self.lastLoggedAt = lastLoggedAt
        self.logCount = logCount
        self.searchTokens = searchTokens
    }
}
