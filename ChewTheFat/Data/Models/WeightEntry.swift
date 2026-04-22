import Foundation
import SwiftData

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double

    var message: Message?

    init(
        id: UUID = UUID(),
        date: Date,
        weightKg: Double,
        message: Message? = nil
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.message = message
    }
}
