import Foundation

/// Drives the scripted Profile FRE: preferred units → sex → age → height →
/// summary. The view renders a transcript from `turns` and binds input
/// controls through `currentStep`. On `commitSummary()` the collected values
/// are written to the `UserProfile` row.
///
/// The flow stays pure-Swift (no SwiftUI import) so it can be unit-tested
/// without running in a host app.
@MainActor
@Observable
final class ProfileFREViewModel {
    enum Step: Equatable, Hashable {
        case units
        case sex
        case age
        case height
        case summary
        case done
    }

    struct Turn: Identifiable, Hashable {
        let id: Step
        let question: String
        let answer: String?
    }

    private(set) var step: Step = .units
    private(set) var turns: [Turn] = []

    var units: PreferredUnitSystem?
    var sex: BiologicalSex?
    /// Raw digits for the keypad; converted to Int on submit.
    var ageInput: String = ""
    /// Raw height string (metric: cm number; imperial: "5-11" / "5'11\"").
    var heightInput: String = ""
    private(set) var ageYears: Int?
    private(set) var heightCm: Double?
    private(set) var errorMessage: String?

    private let profile: ProfileRepository

    init(profile: ProfileRepository) {
        self.profile = profile
        self.turns = [Turn(id: .units, question: Questions.units, answer: nil)]
    }

    // MARK: - Steps

    func selectUnits(_ choice: PreferredUnitSystem) {
        units = choice
        record(step: .units, answer: choice.displayName)
        advance(to: .sex)
    }

    func selectSex(_ choice: BiologicalSex) {
        sex = choice
        record(step: .sex, answer: choice.displayName)
        advance(to: .age)
    }

    func submitAge() {
        errorMessage = nil
        let trimmed = ageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (13...100).contains(value) else {
            errorMessage = "Enter an age between 13 and 100."
            return
        }
        ageYears = value
        record(step: .age, answer: "\(value)")
        advance(to: .height)
    }

    func submitHeight() {
        errorMessage = nil
        let trimmed = heightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cm = HeightParser.parseCentimeters(trimmed) else {
            errorMessage = "Enter a valid height (e.g. 5'11\" or 180 cm)."
            return
        }
        heightCm = cm
        let displayValue = units.map { UnitFormatter.height(cm: cm, in: $0) } ?? trimmed
        record(step: .height, answer: displayValue)
        advance(to: .summary)
    }

    /// Toggles the sex in the summary card (Figma allows editing in place).
    func toggleSummarySex(_ choice: BiologicalSex) {
        sex = choice
        if let index = turns.firstIndex(where: { $0.id == .sex }) {
            turns[index] = Turn(id: .sex, question: Questions.sex, answer: choice.displayName)
        }
    }

    @discardableResult
    func commitSummary() -> Bool {
        errorMessage = nil
        guard
            let units,
            let sex,
            let ageYears,
            let heightCm
        else {
            errorMessage = "Finish each question first."
            return false
        }
        do {
            let current = try profile.current() ?? UserProfile(
                age: ageYears,
                heightCm: heightCm,
                sex: sex.rawValue,
                preferredUnits: units.rawValue,
                activityLevel: ""
            )
            current.age = ageYears
            current.heightCm = heightCm
            current.sex = sex.rawValue
            current.preferredUnits = units.rawValue
            try profile.save(current)
            step = .done
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Derived

    var birthYear: Int? {
        guard let ageYears else { return nil }
        let now = Calendar.current.component(.year, from: .now)
        return now - ageYears
    }

    var heightFeetInches: (feet: Int, inches: Int)? {
        guard let heightCm else { return nil }
        let totalInches = heightCm / UnitFormatter.cmPerInch
        let feet = Int(totalInches / Double(UnitFormatter.inchesPerFoot))
        let inches = Int(totalInches.rounded()) - feet * UnitFormatter.inchesPerFoot
        if inches >= UnitFormatter.inchesPerFoot {
            return (feet + 1, 0)
        }
        return (feet, inches)
    }

    // MARK: - Private

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
        case .units: return Questions.units
        case .sex: return Questions.sex
        case .age: return Questions.age
        case .height: return Questions.height
        case .summary, .done: return ""
        }
    }

    private enum Questions {
        static let units = "What are your preferred units?"
        static let sex = "Biological sex?"
        static let age = "Age?"
        static let height = "Height (e.g. 5' 11\" or 5-11)?"
    }
}
