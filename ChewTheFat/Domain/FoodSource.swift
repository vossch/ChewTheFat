import Foundation

enum FoodSource: String, Codable, Hashable, Sendable, CaseIterable {
    case usda
    case openFoodFacts
    case web
    case manual
}
