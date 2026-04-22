import Foundation

struct ReferenceServing: Hashable, Sendable, Codable {
    let measurementName: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double

    var nutrition: NutritionFacts {
        NutritionFacts(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG
        )
    }
}

struct ReferenceFood: Hashable, Sendable, Codable, Identifiable {
    let source: FoodSource
    let sourceRefId: String
    let name: String
    let detail: String?
    let servings: [ReferenceServing]
    let score: Double

    var id: String { "\(source.rawValue):\(sourceRefId)" }

    init(
        source: FoodSource,
        sourceRefId: String,
        name: String,
        detail: String? = nil,
        servings: [ReferenceServing],
        score: Double = 0
    ) {
        self.source = source
        self.sourceRefId = sourceRefId
        self.name = name
        self.detail = detail
        self.servings = servings
        self.score = score
    }
}
