import Foundation

/// Biological sex required for the Mifflin-St Jeor BMR formula, which
/// differs by ±166 kcal between male and female. Kept separate from the
/// string stored on `UserProfile.sex` so `CalorieBudgetEstimator` stays
/// pure-Swift and SwiftData-free.
enum BiologicalSex: String, Codable, Hashable, Sendable, CaseIterable {
    case male
    case female

    init?(storedValue: String?) {
        guard let raw = storedValue?.lowercased(), !raw.isEmpty else { return nil }
        self.init(rawValue: raw)
    }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

/// Pure-Swift calorie-budget math used by the FRE Goals summary and the
/// Settings Goals editor's Auto mode. No SwiftData / SwiftUI imports so it
/// stays unit-testable without a persistence stack.
enum CalorieBudgetEstimator {
    /// 1 kg of body fat ≈ 7 700 kcal (see `goal-weight-loss.md`).
    static let kcalPerKgBodyFat: Double = 7_700

    /// Mifflin-St Jeor BMR in kcal/day.
    static func bmr(
        sex: BiologicalSex,
        ageYears: Int,
        heightCm: Double,
        weightKg: Double
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Total daily energy expenditure = BMR × activity multiplier.
    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// Daily calorie target for the given weekly weight-change goal.
    /// Positive `weeklyChangeKg` is a surplus; negative is a deficit.
    static func calorieTarget(
        sex: BiologicalSex,
        ageYears: Int,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        weeklyChangeKg: Double
    ) -> Int {
        let bmrValue = bmr(sex: sex, ageYears: ageYears, heightCm: heightCm, weightKg: weightKg)
        let tdeeValue = tdee(bmr: bmrValue, activity: activity)
        let dailyDelta = weeklyChangeKg * kcalPerKgBodyFat / 7
        let raw = tdeeValue + dailyDelta
        return Int(raw.rounded())
    }

    /// Default macro split applied when the user hasn't overridden it:
    /// 30 % protein / 40 % carbs / 30 % fat, converted to grams via
    /// 4 / 4 / 9 kcal per gram.
    struct MacroGrams: Hashable, Sendable {
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
    }

    static func defaultMacros(calorieTarget: Int) -> MacroGrams {
        guard calorieTarget > 0 else {
            return MacroGrams(proteinG: 0, carbsG: 0, fatG: 0)
        }
        let kcal = Double(calorieTarget)
        return MacroGrams(
            proteinG: kcal * 0.30 / 4,
            carbsG: kcal * 0.40 / 4,
            fatG: kcal * 0.30 / 9
        )
    }
}
