import Foundation
import SwiftData

@Model
final class LoggedFood {
    @Attribute(.unique) var id: UUID
    var date: Date
    var meal: String
    var quantity: Double

    var foodEntry: FoodEntry?
    var serving: Serving?
    var message: Message?

    init(
        id: UUID = UUID(),
        date: Date,
        meal: String,
        quantity: Double,
        foodEntry: FoodEntry? = nil,
        serving: Serving? = nil,
        message: Message? = nil
    ) {
        self.id = id
        self.date = date
        self.meal = meal
        self.quantity = quantity
        self.foodEntry = foodEntry
        self.serving = serving
        self.message = message
    }
}
