import Foundation

enum MealType: String, Codable, Hashable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
}

extension MealType {
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
}
