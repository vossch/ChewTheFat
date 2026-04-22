import Foundation
import SwiftData

@Model
final class UserGoals {
    @Attribute(.unique) var id: UUID
    var method: String
    var weeklyChangeKg: Double
    var calorieTarget: Int
    var calorieIsManual: Bool
    var proteinTargetG: Double
    var carbsTargetG: Double
    var fatTargetG: Double
    var macrosAreManual: Bool
    var updatedAt: Date
    var idealWeightKg: Double?

    init(
        id: UUID = UUID(),
        method: String,
        weeklyChangeKg: Double,
        calorieTarget: Int,
        calorieIsManual: Bool = false,
        proteinTargetG: Double,
        carbsTargetG: Double,
        fatTargetG: Double,
        macrosAreManual: Bool = false,
        updatedAt: Date = .now,
        idealWeightKg: Double? = nil
    ) {
        self.id = id
        self.method = method
        self.weeklyChangeKg = weeklyChangeKg
        self.calorieTarget = calorieTarget
        self.calorieIsManual = calorieIsManual
        self.proteinTargetG = proteinTargetG
        self.carbsTargetG = carbsTargetG
        self.fatTargetG = fatTargetG
        self.macrosAreManual = macrosAreManual
        self.updatedAt = updatedAt
        self.idealWeightKg = idealWeightKg
    }
}
