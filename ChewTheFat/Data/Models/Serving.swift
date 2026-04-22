import Foundation
import SwiftData

@Model
final class Serving {
    @Attribute(.unique) var id: UUID
    var measurementName: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double

    var foodEntry: FoodEntry?

    @Relationship(deleteRule: .nullify, inverse: \LoggedFood.serving)
    var loggedFoods: [LoggedFood] = []

    init(
        id: UUID = UUID(),
        measurementName: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double,
        foodEntry: FoodEntry? = nil
    ) {
        self.id = id
        self.measurementName = measurementName
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.foodEntry = foodEntry
    }
}
