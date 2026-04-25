import Foundation

/// Produces the five suggested weight values surfaced by the weigh-in
/// picker (Figma "Weigh-in 1"). Centered on the user's last entry with a
/// 0.2-unit step in the preferred display system, highest value first.
/// Falls back to a neutral baseline when no history exists yet.
enum WeightLogSuggestions {
    static let count = 5
    static let stepDisplay: Double = 0.2
    static let fallbackKg: Double = 80

    /// Returns kg values (highest first). The view converts back to display
    /// units at render time so a units change between save and render stays
    /// truthful.
    static func aroundLatest(
        lastEntryKg: Double?,
        units: PreferredUnitSystem
    ) -> [Double] {
        let baseKg = lastEntryKg ?? fallbackKg
        let baseDisplay = UnitFormatter.weightValue(kg: baseKg, in: units)
        let offsets = Array(-2...2).reversed()
        return offsets.map { offset in
            let display = baseDisplay + Double(offset) * stepDisplay
            return UnitFormatter.weightToKg(display, from: units)
        }
    }
}
