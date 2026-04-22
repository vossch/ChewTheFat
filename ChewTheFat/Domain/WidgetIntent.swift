import Foundation

enum WidgetIntent: Hashable, Sendable, Codable {
    case mealCard(MealCardPayload)
    case macroChart(MacroChartPayload)
    case weightGraph(WeightGraphPayload)
    case quickLog(QuickLogPayload)

    var type: String {
        switch self {
        case .mealCard: return "mealCard"
        case .macroChart: return "macroChart"
        case .weightGraph: return "weightGraph"
        case .quickLog: return "quickLog"
        }
    }
}

struct MealCardPayload: Hashable, Sendable, Codable {
    let loggedFoodIds: [UUID]
    let mealType: MealType
    let date: Date
}

struct MacroChartPayload: Hashable, Sendable, Codable {
    let date: Date
}

struct WeightGraphPayload: Hashable, Sendable, Codable {
    let dateRange: DateRange

    struct DateRange: Hashable, Sendable, Codable {
        let start: Date
        let end: Date
    }
}

struct QuickLogPayload: Hashable, Sendable, Codable {
    let candidateFoodEntryIds: [UUID]
    let prompt: String
}
