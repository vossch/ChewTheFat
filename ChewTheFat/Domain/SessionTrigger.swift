import Foundation

/// What kind of session the app should auto-start when the user opens it,
/// given the time of day and what they've already logged today.
///
/// Pure value type; the caller plugs in the data via the inputs and decides
/// whether to actually create a session based on `recommendedGoal` and
/// `slotId` (used to suppress double-firing within the same window).
nonisolated struct SessionTrigger: Hashable, Sendable {
    let recommendedGoal: SessionGoal
    let mealType: MealType?
    let promptText: String?
    let suggestions: [String]
    let slotId: String

    /// Returns true if the trigger is asking the caller to seed a new session
    /// (i.e. anything other than `.general`).
    var shouldAutoStart: Bool { recommendedGoal != .general }

    static let general = SessionTrigger(
        recommendedGoal: .general,
        mealType: nil,
        promptText: nil,
        suggestions: [],
        slotId: "general"
    )
}

extension SessionTrigger {
    struct Inputs {
        let now: Date
        let lastWeightLogDate: Date?
        let loggedMealsToday: Set<MealType>
        let recentMealSummaries: (MealType) -> [String]
        let calendar: Calendar

        init(
            now: Date = .now,
            lastWeightLogDate: Date?,
            loggedMealsToday: Set<MealType>,
            recentMealSummaries: @escaping (MealType) -> [String],
            calendar: Calendar = .current
        ) {
            self.now = now
            self.lastWeightLogDate = lastWeightLogDate
            self.loggedMealsToday = loggedMealsToday
            self.recentMealSummaries = recentMealSummaries
            self.calendar = calendar
        }
    }

    /// Slot windows in local hours. Earlier slots win when overlapping —
    /// weigh-in fires before breakfast even though both run in the morning.
    private struct Slot {
        let id: String
        let startHour: Int
        let endHour: Int
        let goal: SessionGoal
        let mealType: MealType?
    }

    private static let slots: [Slot] = [
        Slot(id: "weighIn", startHour: 5, endHour: 11, goal: .logWeight, mealType: nil),
        Slot(id: "breakfast", startHour: 7, endHour: 11, goal: .logMeal, mealType: .breakfast),
        Slot(id: "lunch", startHour: 11, endHour: 15, goal: .logMeal, mealType: .lunch),
        Slot(id: "dinner", startHour: 17, endHour: 21, goal: .logMeal, mealType: .dinner)
    ]

    static func evaluate(_ inputs: Inputs) -> SessionTrigger {
        let cal = inputs.calendar
        let hour = cal.component(.hour, from: inputs.now)
        let dayKey = dayKey(for: inputs.now, calendar: cal)

        for slot in slots where (slot.startHour..<slot.endHour).contains(hour) {
            switch slot.goal {
            case .logWeight:
                if !weightLoggedToday(inputs: inputs) {
                    return SessionTrigger(
                        recommendedGoal: .logWeight,
                        mealType: nil,
                        promptText: "Time to weigh in. Where are you today?",
                        suggestions: [],
                        slotId: "weighIn-\(dayKey)"
                    )
                }
            case .logMeal:
                guard let meal = slot.mealType,
                      !inputs.loggedMealsToday.contains(meal) else { continue }
                let suggestions = inputs.recentMealSummaries(meal)
                return SessionTrigger(
                    recommendedGoal: .logMeal,
                    mealType: meal,
                    promptText: prompt(for: meal, hasSuggestions: !suggestions.isEmpty),
                    suggestions: suggestions,
                    slotId: "\(slot.id)-\(dayKey)"
                )
            default:
                continue
            }
        }
        return .general
    }

    private static func weightLoggedToday(inputs: Inputs) -> Bool {
        guard let last = inputs.lastWeightLogDate else { return false }
        return inputs.calendar.isDate(last, inSameDayAs: inputs.now)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private static func prompt(for meal: MealType, hasSuggestions: Bool) -> String {
        if hasSuggestions {
            return "What did you have for \(meal.rawValue)? Tap one if it matches."
        }
        return "What did you have for \(meal.rawValue)?"
    }
}
