import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var age: Int
    var heightCm: Double
    var sex: String
    var preferredUnits: String
    var activityLevel: String
    var createdAt: Date
    var eulaAcceptedAt: Date?

    init(
        id: UUID = UUID(),
        age: Int,
        heightCm: Double,
        sex: String,
        preferredUnits: String,
        activityLevel: String,
        createdAt: Date = .now,
        eulaAcceptedAt: Date? = nil
    ) {
        self.id = id
        self.age = age
        self.heightCm = heightCm
        self.sex = sex
        self.preferredUnits = preferredUnits
        self.activityLevel = activityLevel
        self.createdAt = createdAt
        self.eulaAcceptedAt = eulaAcceptedAt
    }
}
