import Foundation

enum ActivityLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case heavy

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .heavy: return 1.725
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .heavy: return "Very active"
        }
    }
}
