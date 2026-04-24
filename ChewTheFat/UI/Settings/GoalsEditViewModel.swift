import Foundation

/// Backs the Goals editor screen (US6, FR-023). Two modes:
///
/// - **Auto**: calorie target is derived from profile + activity + weekly change
///   (Mifflin-St. Jeor, per `skill-calorie-budgeting.md`). Macros follow the
///   default 30/40/30 split unless the user has overridden them.
/// - **Manual**: user types a calorie target and/or drags macro percentage
///   sliders. Dragging one slider auto-rebalances the other two so the three
///   always sum to 100 % (FR-023 invariant).
///
/// Percentages are the edit surface; grams are derived on save.
@MainActor
@Observable
final class GoalsEditViewModel {
    enum Method: String, CaseIterable, Hashable {
        case auto
        case manual

        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .manual: return "Manual"
            }
        }
    }

    var method: Method = .auto
    var calorieTarget: Int = 2000
    var weeklyChangeKg: Double = 0
    var idealWeightKg: Double?
    /// Raw display value for the ideal-weight field (keeps imperial input stable).
    var idealWeightInput: String = ""
    var preferredUnits: PreferredUnitSystem = .metric

    /// Percentages — always sum to 100 via `adjust(_:to:)`.
    private(set) var proteinPct: Double = 30
    private(set) var carbsPct: Double = 40
    private(set) var fatPct: Double = 30
    private(set) var errorMessage: String?

    private let goals: GoalRepository
    private let profile: ProfileRepository

    init(goals: GoalRepository, profile: ProfileRepository) {
        self.goals = goals
        self.profile = profile
    }

    func load() {
        self.preferredUnits = PreferredUnitSystem(
            storedValue: (try? profile.current())?.preferredUnits
        )
        guard let current = (try? goals.current()) else {
            self.idealWeightInput = ""
            return
        }
        self.method = current.calorieIsManual || current.macrosAreManual ? .manual : .auto
        self.calorieTarget = current.calorieTarget
        self.weeklyChangeKg = current.weeklyChangeKg
        self.idealWeightKg = current.idealWeightKg
        if let ideal = current.idealWeightKg {
            self.idealWeightInput = Self.formatWeight(ideal, in: preferredUnits)
        }
        let total = current.proteinTargetG * 4 + current.carbsTargetG * 4 + current.fatTargetG * 9
        if total > 0 {
            self.proteinPct = (current.proteinTargetG * 4 / total) * 100
            self.carbsPct = (current.carbsTargetG * 4 / total) * 100
            self.fatPct = (current.fatTargetG * 9 / total) * 100
            normalize()
        }
    }

    enum Macro { case protein, carbs, fat }

    /// Updates the dragged macro to `newValue` and spreads the delta across
    /// the other two in proportion to their prior share, so the three always
    /// sum to exactly 100. If the other two are both zero, the delta splits
    /// evenly.
    func adjust(_ macro: Macro, to newValue: Double) {
        let clamped = max(0, min(100, newValue))
        let currentValue: Double
        let other1KP: WritableKeyPath<GoalsEditViewModel, Double>
        let other2KP: WritableKeyPath<GoalsEditViewModel, Double>
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
            new1 = 0
            new2 = 0
        } else if otherSum <= 0 {
            new1 = remaining / 2
            new2 = remaining / 2
        } else {
            new1 = max(0, other1 - delta * (other1 / otherSum))
            new2 = max(0, other2 - delta * (other2 / otherSum))
        }

        switch macro {
        case .protein:
            proteinPct = clamped
            carbsPct = new1
            fatPct = new2
        case .carbs:
            carbsPct = clamped
            proteinPct = new1
            fatPct = new2
        case .fat:
            fatPct = clamped
            proteinPct = new1
            carbsPct = new2
        }
        normalize()
    }

    @discardableResult
    func save() -> Bool {
        errorMessage = nil

        let trimmed = idealWeightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let parsed = Self.parseWeight(trimmed, in: preferredUnits), parsed > 0 else {
                errorMessage = "Enter a valid ideal weight."
                return false
            }
            self.idealWeightKg = parsed
        }

        let existing = (try? goals.current())
        let isManual = method == .manual
        let protein = calorieTarget > 0 ? (proteinPct / 100) * Double(calorieTarget) / 4 : 0
        let carbs = calorieTarget > 0 ? (carbsPct / 100) * Double(calorieTarget) / 4 : 0
        let fat = calorieTarget > 0 ? (fatPct / 100) * Double(calorieTarget) / 9 : 0

        do {
            if let existing {
                existing.method = isManual ? "manual" : "auto"
                existing.calorieTarget = calorieTarget
                existing.calorieIsManual = isManual
                existing.weeklyChangeKg = weeklyChangeKg
                existing.idealWeightKg = idealWeightKg
                existing.proteinTargetG = protein
                existing.carbsTargetG = carbs
                existing.fatTargetG = fat
                existing.macrosAreManual = isManual
                try goals.save(existing)
            } else {
                let fresh = UserGoals(
                    method: isManual ? "manual" : "auto",
                    weeklyChangeKg: weeklyChangeKg,
                    calorieTarget: calorieTarget,
                    calorieIsManual: isManual,
                    proteinTargetG: protein,
                    carbsTargetG: carbs,
                    fatTargetG: fat,
                    macrosAreManual: isManual,
                    idealWeightKg: idealWeightKg
                )
                try goals.save(fresh)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Rounds to one decimal and forces the three to sum to exactly 100.
    private func normalize() {
        let rounded: [Double] = [proteinPct, carbsPct, fatPct].map { (($0 * 10).rounded() / 10) }
        var p = rounded[0]
        var c = rounded[1]
        var f = rounded[2]
        let total = p + c + f
        if total != 100 {
            // Dump the residual into the largest slice so rounding drift never
            // desyncs the UI from the invariant.
            let residual = 100 - total
            if p >= c && p >= f { p += residual }
            else if c >= f { c += residual }
            else { f += residual }
        }
        proteinPct = p
        carbsPct = c
        fatPct = f
    }

    private static func formatWeight(_ kg: Double, in system: PreferredUnitSystem) -> String {
        switch system {
        case .metric:
            return String(format: "%.1f", kg)
        case .imperial:
            let lb = kg / UnitFormatter.kgPerLb
            return String(format: "%.1f", lb)
        }
    }

    private static func parseWeight(_ raw: String, in system: PreferredUnitSystem) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned) else { return nil }
        return UnitFormatter.weightToKg(value, from: system)
    }
}
