import Foundation

/// Drives the weigh-in picker (Figma "Weigh-in"). Starts expanded with five
/// suggestion rows around the user's last entry; collapses after a tap so
/// the title card still fills the empty chat on return. The view forwards
/// tap values up through WidgetRenderer → ChatView → ChatViewModel.send,
/// so picks flow through the same orchestrator path as typing.
@MainActor
@Observable
final class WeightLogPromptViewModel {
    struct Option: Identifiable, Hashable {
        let id: Int
        let kg: Double
        let displayValue: Double
        let label: String
        let isSameAsLast: Bool
    }

    private(set) var options: [Option] = []
    private(set) var isCollapsed: Bool = false
    let title: String = "Time to weigh in"
    let subtitle: String = "Where are you today?"
    let unitLabel: String

    private let payload: WeightLogPromptPayload
    private let units: PreferredUnitSystem

    init(payload: WeightLogPromptPayload) {
        self.payload = payload
        self.units = PreferredUnitSystem(storedValue: payload.preferredUnits)
        self.unitLabel = UnitFormatter.weightUnitLabel(units)
        self.options = Self.buildOptions(
            suggestionsKg: payload.suggestionsKg,
            lastEntryKg: payload.lastEntryKg,
            units: units
        )
    }

    /// Represents a tap choice as a short reply string the orchestrator
    /// parses like a typed weight. Kept unit-qualified so the model can
    /// log unambiguously.
    func replyText(for option: Option) -> String {
        "\(formatted(option.displayValue)) \(unitLabel)"
    }

    func markCollapsed() {
        isCollapsed = true
    }

    private static func buildOptions(
        suggestionsKg: [Double],
        lastEntryKg: Double?,
        units: PreferredUnitSystem
    ) -> [Option] {
        suggestionsKg.enumerated().map { offset, kg in
            let displayValue = UnitFormatter.weightValue(kg: kg, in: units)
            let isSame: Bool = {
                guard let last = lastEntryKg else { return false }
                let lastDisplay = UnitFormatter.weightValue(kg: last, in: units)
                return abs(displayValue - lastDisplay) < 0.05
            }()
            let base = formatted(displayValue)
            let label = isSame ? "\(base) — Same as yesterday" : base
            return Option(
                id: offset,
                kg: kg,
                displayValue: displayValue,
                label: label,
                isSameAsLast: isSame
            )
        }
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatted(_ value: Double) -> String {
        Self.formatted(value)
    }
}
