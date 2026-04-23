import Foundation

/// Validates a freshly parsed `WidgetIntent` against the current data store
/// before letting the orchestrator emit it. Today this is a thin pass-through;
/// when the model starts emitting widgets directly with stale ids, this is
/// where the cleanup belongs.
@MainActor
struct WidgetIntentResolver {
    let foodLog: FoodLogRepository
    let weightLog: WeightLogRepository

    func resolve(_ intent: WidgetIntent) -> WidgetIntent? {
        switch intent {
        case .mealCard(let payload):
            let valid = payload.loggedFoodIds.filter { id in
                guard let day = (try? foodLog.loggedFoods(on: payload.date)) else { return false }
                return day.contains(where: { $0.id == id })
            }
            guard !valid.isEmpty else { return nil }
            return .mealCard(MealCardPayload(loggedFoodIds: valid, mealType: payload.mealType, date: payload.date))
        case .macroChart, .weightGraph, .quickLog:
            return intent
        }
    }
}
