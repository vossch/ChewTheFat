import Foundation

nonisolated struct ToolIdentifier: Hashable, Sendable, Codable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    var description: String { rawValue }
}

extension ToolIdentifier {
    static let foodSearch: ToolIdentifier = "food_search"
    static let lookupKnowledge: ToolIdentifier = "lookup_knowledge"
    static let logFood: ToolIdentifier = "log_food"
    static let logWeight: ToolIdentifier = "log_weight"
    static let setGoals: ToolIdentifier = "set_goals"
    static let setProfileInfo: ToolIdentifier = "set_profile_info"
}
