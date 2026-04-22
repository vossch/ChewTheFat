import Foundation

enum SessionGoal: String, Codable, Hashable, Sendable, CaseIterable {
    case onboarding
    case logMeal
    case logWeight
    case userInsights
    case general
}
