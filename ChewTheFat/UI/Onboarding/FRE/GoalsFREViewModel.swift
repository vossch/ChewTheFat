import Foundation

/// Drives the scripted Goals FRE: weekly-change preset → activity level →
/// current weight → ideal weight (with BMI-derived suggestions) → summary.
///
/// The summary supports Auto mode (calories + macros derived from profile via
/// `CalorieBudgetEstimator`) and Manual mode (user types calories and drags
/// macro percentages). Persisting writes the `UserGoals` row, updates
/// `UserProfile.activityLevel`, and logs the current weight through
/// `WeightLogRepository`.
@MainActor
@Observable
final class GoalsFREViewModel {
    enum Step: Equatable, Hashable {
        case weeklyChange
        case activity
        case currentWeight
        case idealWeight
        case summary
        case done
    }

    enum Method: String, Hashable, CaseIterable {
        case auto
        case manual
        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .manual: return "Manual"
            }
        }
    }

    struct WeeklyChangeOption: Identifiable, Hashable {
        let kgPerWeek: Double
        var id: String { String(format: "%.3f", kgPerWeek) }
        var title: String {
            switch kgPerWeek {
            case ..<(-0.6): return "Lose weight very quickly"
            case -0.6 ..< -0.3: return "Lose weight quickly"
            case -0.3 ..< -0.05: return "Lose weight"
            case -0.05 ... 0.05: return "Maintain weight"
            case 0.05 ..< 0.3: return "Gain weight"
            default: return "Gain weight quickly"
            }
        }
        var subtitle: String {
            let lbs = kgPerWeek / UnitFormatter.kgPerLb
            if abs(lbs) < 0.05 { return "0 lbs/week" }
            let sign = lbs > 0 ? "+" : "−"
            return "\(sign)\(String(format: "%.1f", abs(lbs))) lbs/week"
        }
    }

    struct IdealWeightSuggestion: Identifiable, Hashable {
        let kg: Double
        let label: String
        var id: String { "\(label)-\(Int(kg.rounded()))" }
    }

    struct Turn: Identifiable, Hashable {
        let id: Step
        let question: String
        let answer: String?
    }

    private(set) var step: Step = .weeklyChange
    private(set) var turns: [Turn]

    var method: Method = .auto
    var weeklyChange: WeeklyChangeOption?
    var activity: ActivityLevel?
    /// Raw digits for the current-weight keypad, in the user's preferred unit.
    var currentWeightInput: String = ""
    var idealWeightInput: String = ""
    private(set) var currentWeightKg: Double?
    private(set) var idealWeightKg: Double?

    /// Manual-mode calorie + macro overrides.
    var manualCalories: Int = 2000
    private(set) var proteinPct: Double = 30
    private(set) var carbsPct: Double = 40
    private(set) var fatPct: Double = 30

    private(set) var errorMessage: String?

    private let goals: GoalRepository
    private let profile: ProfileRepository
    private let weightLog: WeightLogRepository
    private let preferredUnits: PreferredUnitSystem

    init(
        goals: GoalRepository,
        profile: ProfileRepository,
        weightLog: WeightLogRepository
    ) {
        self.goals = goals
        self.profile = profile
        self.weightLog = weightLog
        self.preferredUnits = PreferredUnitSystem(
            storedValue: (try? profile.current())?.preferredUnits
        )
        self.turns = [Turn(id: .weeklyChange, question: Questions.weeklyChange, answer: nil)]
    }

    static let weeklyChangeOptions: [WeeklyChangeOption] = [
        // -1.5 lb/wk → -0.68 kg/wk
        WeeklyChangeOption(kgPerWeek: -1.5 * UnitFormatter.kgPerLb),
        // -1 lb/wk
        WeeklyChangeOption(kgPerWeek: -1.0 * UnitFormatter.kgPerLb),
        // -0.5 lb/wk
        WeeklyChangeOption(kgPerWeek: -0.5 * UnitFormatter.kgPerLb),
        // maintain
        WeeklyChangeOption(kgPerWeek: 0),
        // +0.5 lb/wk
        WeeklyChangeOption(kgPerWeek: 0.5 * UnitFormatter.kgPerLb)
    ]

    static let activityOptions: [ActivityLevel] = ActivityLevel.allCases

    // MARK: - Steps

    func selectWeeklyChange(_ option: WeeklyChangeOption) {
        weeklyChange = option
        record(step: .weeklyChange, answer: option.title)
        advance(to: .activity)
    }

    func selectActivity(_ level: ActivityLevel) {
        activity = level
        record(step: .activity, answer: level.displayName)
        advance(to: .currentWeight)
    }

    func submitCurrentWeight() {
        errorMessage = nil
        let trimmed = currentWeightInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0 else {
            errorMessage = "Enter a valid weight."
            return
        }
        let kg = UnitFormatter.weightToKg(value, from: preferredUnits)
        guard (20...400).contains(kg) else {
            errorMessage = "Enter a weight between 20 and 400 kg."
            return
        }
        currentWeightKg = kg
        record(step: .currentWeight, answer: answerText(for: value))
        advance(to: .idealWeight)
    }

    func selectIdealWeight(_ suggestion: IdealWeightSuggestion) {
        idealWeightKg = suggestion.kg
        let display = UnitFormatter.weightValue(kg: suggestion.kg, in: preferredUnits)
        idealWeightInput = String(Int(display.rounded()))
        record(step: .idealWeight, answer: "\(Int(display.rounded()))")
        advance(to: .summary)
    }

    func submitCustomIdealWeight() {
        errorMessage = nil
        let trimmed = idealWeightInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0 else {
            errorMessage = "Enter a valid ideal weight."
            return
        }
        let kg = UnitFormatter.weightToKg(value, from: preferredUnits)
        idealWeightKg = kg
        record(step: .idealWeight, answer: answerText(for: value))
        advance(to: .summary)
    }

    // MARK: - Summary edits

    func adjustMacro(_ macro: GoalsFREViewModel.Macro, to newValue: Double) {
        let clamped = max(0, min(100, newValue))
        let currentValue: Double
        let other1KP: WritableKeyPath<GoalsFREViewModel, Double>
        let other2KP: WritableKeyPath<GoalsFREViewModel, Double>
        switch macro {
        case .protein:
            currentValue = proteinPct
            other1KP = \.carbsPct
            other2KP = \.fatPct
        case .carbs:
            currentValue = carbsPct
            other1KP = \.proteinPct
            other2KP = \.fatPct
        case .fat:
            currentValue = fatPct
            other1KP = \.proteinPct
            other2KP = \.carbsPct
        }
        let delta = clamped - currentValue
        let other1 = self[keyPath: other1KP]
        let other2 = self[keyPath: other2KP]
        let otherSum = other1 + other2
        let remaining = 100 - clamped

        let new1: Double
        let new2: Double
        if remaining <= 0 {
            new1 = 0; new2 = 0
        } else if otherSum <= 0 {
            new1 = remaining / 2; new2 = remaining / 2
        } else {
            new1 = max(0, other1 - delta * (other1 / otherSum))
            new2 = max(0, other2 - delta * (other2 / otherSum))
        }
        switch macro {
        case .protein: proteinPct = clamped; carbsPct = new1; fatPct = new2
        case .carbs: carbsPct = clamped; proteinPct = new1; fatPct = new2
        case .fat: fatPct = clamped; proteinPct = new1; carbsPct = new2
        }
        normalizeMacros()
    }

    enum Macro { case protein, carbs, fat }

    // MARK: - Derived summary

    /// Calorie target shown on the summary card. Auto mode derives it via
    /// `CalorieBudgetEstimator`; Manual mode mirrors `manualCalories`.
    var summaryCalories: Int {
        switch method {
        case .manual:
            return manualCalories
        case .auto:
            guard
                let profile = try? profile.current(),
                let sex = BiologicalSex(storedValue: profile.sex),
                let activity,
                let weeklyChange,
                let weightKg = currentWeightKg,
                profile.age > 0,
                profile.heightCm > 0
            else { return 0 }
            return CalorieBudgetEstimator.calorieTarget(
                sex: sex,
                ageYears: profile.age,
                heightCm: profile.heightCm,
                weightKg: weightKg,
                activity: activity,
                weeklyChangeKg: weeklyChange.kgPerWeek
            )
        }
    }

    var summaryMacros: CalorieBudgetEstimator.MacroGrams {
        switch method {
        case .auto:
            return CalorieBudgetEstimator.defaultMacros(calorieTarget: summaryCalories)
        case .manual:
            let kcal = Double(manualCalories)
            return CalorieBudgetEstimator.MacroGrams(
                proteinG: kcal * proteinPct / 100 / 4,
                carbsG: kcal * carbsPct / 100 / 4,
                fatG: kcal * fatPct / 100 / 9
            )
        }
    }

    /// Projected date to reach idealWeight, or nil if indefinite / missing data.
    var projectedGoalDate: Date? {
        guard
            let idealWeightKg,
            let currentWeightKg,
            let weeklyChange,
            abs(weeklyChange.kgPerWeek) > 0.0001
        else { return nil }
        let gap = idealWeightKg - currentWeightKg
        if abs(gap) < 0.25 { return nil }
        // Only project if the weekly change points toward the goal.
        if (gap > 0 && weeklyChange.kgPerWeek <= 0) ||
           (gap < 0 && weeklyChange.kgPerWeek >= 0) {
            return nil
        }
        let perDay = weeklyChange.kgPerWeek / 7
        let days = gap / perDay
        guard days.isFinite, days > 0, days < 365 * 5 else { return nil }
        return Date.now.addingTimeInterval(days * 24 * 60 * 60)
    }

    // MARK: - Ideal-weight suggestions

    /// BMI-derived suggestions for the ideal-weight picker. If height isn't
    /// available yet we fall back to a single suggestion matching current
    /// weight so the user can still pick-and-move.
    var idealWeightSuggestions: [IdealWeightSuggestion] {
        guard
            let heightCm = (try? profile.current())?.heightCm, heightCm > 0
        else { return [] }
        let heightM = heightCm / 100
        let heightSq = heightM * heightM
        let bands: [(bmi: Double, label: String)] = [
            (25.5, "Moderate weight lifter"),
            (23.5, "Light weight lifter"),
            (22.0, "Healthy"),
            (20.5, "Lean endurance runner")
        ]
        return bands.map { band in
            IdealWeightSuggestion(kg: band.bmi * heightSq, label: band.label)
        }
    }

    // MARK: - Persist

    @discardableResult
    func commitSummary() -> Bool {
        errorMessage = nil
        guard
            let weeklyChange,
            let activity,
            let currentWeightKg,
            let idealWeightKg
        else {
            errorMessage = "Finish each question first."
            return false
        }
        do {
            // Write activity level onto the profile row so downstream TDEE
            // calculations (and the agent context) can see it.
            if let current = try profile.current() {
                current.activityLevel = activity.rawValue
                try profile.save(current)
            }

            let calories = summaryCalories
            let macros = summaryMacros
            let isManual = method == .manual

            if let existing = try goals.current() {
                existing.method = method.rawValue
                existing.weeklyChangeKg = weeklyChange.kgPerWeek
                existing.calorieTarget = calories
                existing.calorieIsManual = isManual
                existing.proteinTargetG = macros.proteinG
                existing.carbsTargetG = macros.carbsG
                existing.fatTargetG = macros.fatG
                existing.macrosAreManual = isManual
                existing.idealWeightKg = idealWeightKg
                try goals.save(existing)
            } else {
                let fresh = UserGoals(
                    method: method.rawValue,
                    weeklyChangeKg: weeklyChange.kgPerWeek,
                    calorieTarget: calories,
                    calorieIsManual: isManual,
                    proteinTargetG: macros.proteinG,
                    carbsTargetG: macros.carbsG,
                    fatTargetG: macros.fatG,
                    macrosAreManual: isManual,
                    idealWeightKg: idealWeightKg
                )
                try goals.save(fresh)
            }

            _ = try weightLog.log(weightKg: currentWeightKg, date: .now)
            step = .done
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Unit helpers

    var weightUnitLabel: String { UnitFormatter.weightUnitLabel(preferredUnits) }
    var preferredUnitSystem: PreferredUnitSystem { preferredUnits }

    // MARK: - Private

    private func answerText(for displayValue: Double) -> String {
        let rounded = Int(displayValue.rounded())
        return String(rounded)
    }

    private func record(step: Step, answer: String) {
        if let index = turns.firstIndex(where: { $0.id == step }) {
            turns[index] = Turn(id: step, question: turns[index].question, answer: answer)
        } else {
            turns.append(Turn(id: step, question: questionFor(step), answer: answer))
        }
    }

    private func advance(to next: Step) {
        step = next
        if turns.last?.id != next && next != .done {
            turns.append(Turn(id: next, question: questionFor(next), answer: nil))
        }
    }

    private func questionFor(_ step: Step) -> String {
        switch step {
        case .weeklyChange: return Questions.weeklyChange
        case .activity: return Questions.activity
        case .currentWeight: return Questions.currentWeight
        case .idealWeight: return Questions.idealWeight
        case .summary, .done: return ""
        }
    }

    private func normalizeMacros() {
        let rounded = [proteinPct, carbsPct, fatPct].map { (($0 * 10).rounded() / 10) }
        var p = rounded[0]; var c = rounded[1]; var f = rounded[2]
        let total = p + c + f
        if total != 100 {
            let residual = 100 - total
            if p >= c && p >= f { p += residual }
            else if c >= f { c += residual }
            else { f += residual }
        }
        proteinPct = p; carbsPct = c; fatPct = f
    }

    private enum Questions {
        static let weeklyChange = "What are you trying to do?"
        static let activity = "How active are you?"
        static let currentWeight = "What is your current weight?"
        static let idealWeight = "What's your ideal weight?"
    }
}
