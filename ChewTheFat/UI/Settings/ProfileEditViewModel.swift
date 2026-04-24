import Foundation

/// Backs the Profile editor screen. Loads the single `UserProfile` row, maps
/// it to form fields, and persists edits back through `ProfileRepository`.
/// Display values are shown in the user's preferred unit system; canonical
/// storage always stays metric (cm).
@MainActor
@Observable
final class ProfileEditViewModel {
    var preferredUnits: PreferredUnitSystem = .metric
    var sex: String = ""
    var activityLevel: ActivityLevel = .sedentary
    /// Raw user string so imperial input like "5'11\"" round-trips cleanly.
    var heightInput: String = ""
    var birthYear: Int = Calendar.current.component(.year, from: .now) - 30
    private(set) var errorMessage: String?

    let sexOptions: [String] = ["female", "male", "other"]
    private let profile: ProfileRepository

    init(profile: ProfileRepository) {
        self.profile = profile
    }

    var birthYearRange: ClosedRange<Int> {
        let now = Calendar.current.component(.year, from: .now)
        return (now - 100)...(now - 13)
    }

    func load() {
        guard let current = (try? profile.current()) else { return }
        self.preferredUnits = PreferredUnitSystem(storedValue: current.preferredUnits)
        self.sex = current.sex
        self.activityLevel = ActivityLevel(rawValue: current.activityLevel) ?? .sedentary
        if current.heightCm > 0 {
            self.heightInput = UnitFormatter.height(
                cm: current.heightCm,
                in: preferredUnits
            )
        }
        if current.age > 0 {
            let now = Calendar.current.component(.year, from: .now)
            self.birthYear = now - current.age
        }
    }

    /// Writes the form back into the persisted profile. Returns true if save
    /// succeeded; any validation or persistence error is surfaced through
    /// `errorMessage` and the view can present it.
    @discardableResult
    func save() -> Bool {
        errorMessage = nil

        let trimmedHeight = heightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeight.isEmpty, let heightCm = HeightParser.parseCentimeters(trimmedHeight) else {
            errorMessage = "Enter a valid height (e.g. 5'11\" or 180 cm)."
            return false
        }
        guard sexOptions.contains(sex) else {
            errorMessage = "Pick a biological sex."
            return false
        }

        let year = Calendar.current.component(.year, from: .now)
        let age = max(0, year - birthYear)

        do {
            let current = try profile.current() ?? UserProfile(
                age: age,
                heightCm: heightCm,
                sex: sex,
                preferredUnits: preferredUnits.rawValue,
                activityLevel: activityLevel.rawValue
            )
            current.age = age
            current.heightCm = heightCm
            current.sex = sex
            current.preferredUnits = preferredUnits.rawValue
            current.activityLevel = activityLevel.rawValue
            try profile.save(current)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
