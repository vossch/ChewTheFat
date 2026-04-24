import Foundation

/// Display-only conversions between metric (the canonical storage form) and
/// imperial units. Canonical storage stays kg/cm/g — switching the user's
/// `preferredUnits` must never mutate stored values, it only changes how they
/// render.
enum PreferredUnitSystem: String, CaseIterable, Sendable {
    case metric
    case imperial

    init(storedValue: String?) {
        switch storedValue?.lowercased() {
        case "imperial": self = .imperial
        default: self = .metric
        }
    }

    var displayName: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lb, ft/in)"
        }
    }
}

enum UnitFormatter {
    static let kgPerLb: Double = 0.45359237
    static let cmPerInch: Double = 2.54
    static let inchesPerFoot: Int = 12

    // MARK: Weight

    static func weight(
        kg: Double,
        in system: PreferredUnitSystem,
        fractionDigits: Int = 1
    ) -> String {
        switch system {
        case .metric:
            return "\(formatted(kg, fractionDigits: fractionDigits)) kg"
        case .imperial:
            return "\(formatted(kg / kgPerLb, fractionDigits: fractionDigits)) lb"
        }
    }

    static func weightValue(kg: Double, in system: PreferredUnitSystem) -> Double {
        switch system {
        case .metric: return kg
        case .imperial: return kg / kgPerLb
        }
    }

    static func weightToKg(_ value: Double, from system: PreferredUnitSystem) -> Double {
        switch system {
        case .metric: return value
        case .imperial: return value * kgPerLb
        }
    }

    static func weightUnitLabel(_ system: PreferredUnitSystem) -> String {
        switch system {
        case .metric: return "kg"
        case .imperial: return "lb"
        }
    }

    // MARK: Height

    static func height(
        cm: Double,
        in system: PreferredUnitSystem
    ) -> String {
        switch system {
        case .metric:
            return "\(Int(cm.rounded())) cm"
        case .imperial:
            let totalInches = cm / cmPerInch
            let feet = Int(totalInches / Double(inchesPerFoot))
            let inches = Int(totalInches.rounded()) - feet * inchesPerFoot
            // Rounding 11.6 up to 12 would leave us at 5'12" — normalize.
            if inches >= inchesPerFoot {
                return "\(feet + 1)′0″"
            }
            return "\(feet)′\(inches)″"
        }
    }

    // MARK: Macros / calories

    static func grams(_ g: Double, fractionDigits: Int = 0) -> String {
        "\(formatted(g, fractionDigits: fractionDigits)) g"
    }

    static func calories(_ kcal: Int) -> String {
        "\(kcal) kcal"
    }

    // MARK: Helpers

    private static func formatted(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
