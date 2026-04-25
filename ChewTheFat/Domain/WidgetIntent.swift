import Foundation

nonisolated enum WidgetIntent: Hashable, Sendable, Codable {
    case mealCard(MealCardPayload)
    case macroChart(MacroChartPayload)
    case weightGraph(WeightGraphPayload)
    case weightLogPrompt(WeightLogPromptPayload)
    case quickLog(QuickLogPayload)

    var type: String {
        switch self {
        case .mealCard: return "mealCard"
        case .macroChart: return "macroChart"
        case .weightGraph: return "weightGraph"
        case .weightLogPrompt: return "weightLogPrompt"
        case .quickLog: return "quickLog"
        }
    }
}

nonisolated struct MealCardPayload: Hashable, Sendable, Codable {
    let loggedFoodIds: [UUID]
    let mealType: MealType
    let date: Date
}

nonisolated struct MacroChartPayload: Hashable, Sendable, Codable {
    let date: Date
}

nonisolated struct WeightGraphPayload: Hashable, Sendable, Codable {
    let dateRange: DateRange

    nonisolated struct DateRange: Hashable, Sendable, Codable {
        let start: Date
        let end: Date
    }
}

nonisolated struct WeightLogPromptPayload: Hashable, Sendable, Codable {
    let suggestionsKg: [Double]
    let lastEntryKg: Double?
    let preferredUnits: String
}

nonisolated struct QuickLogPayload: Hashable, Sendable, Codable {
    let candidateFoodEntryIds: [UUID]
    let prompt: String
}
