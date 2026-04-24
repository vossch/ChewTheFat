import Foundation

enum ActivityLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case heavy
    case athlete

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .heavy: return 1.725
        case .athlete: return 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .heavy: return "Very active"
        case .athlete: return "Athlete"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Desk job, no exercise"
        case .light: return "1–2 times/week"
        case .moderate: return "3–4 times/week"
        case .heavy: return "Active job or daily exercise"
        case .athlete: return "Training most days"
        }
    }
}
