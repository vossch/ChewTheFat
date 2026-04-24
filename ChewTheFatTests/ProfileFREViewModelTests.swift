import XCTest
@testable import ChewTheFat

@MainActor
final class ProfileFREViewModelTests: XCTestCase {
    func testStartsOnUnitsStepWithFirstQuestion() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)

        XCTAssertEqual(vm.step, .units)
        XCTAssertEqual(vm.turns.count, 1)
        XCTAssertEqual(vm.turns.first?.id, .units)
        XCTAssertNil(vm.turns.first?.answer)
    }

    func testSelectingUnitsAdvancesToSexStep() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)

        vm.selectUnits(.imperial)

        XCTAssertEqual(vm.step, .sex)
        XCTAssertEqual(vm.units, .imperial)
        XCTAssertEqual(vm.turns.first?.answer, PreferredUnitSystem.imperial.displayName)
        XCTAssertTrue(vm.turns.contains(where: { $0.id == .sex && $0.answer == nil }))
    }

    func testAgeRejectsOutOfRangeValues() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)
        vm.selectUnits(.metric)
        vm.selectSex(.male)

        vm.ageInput = "9"
        vm.submitAge()
        XCTAssertEqual(vm.step, .age, "too-young age should not advance")
        XCTAssertNotNil(vm.errorMessage)

        vm.ageInput = "45"
        vm.submitAge()
        XCTAssertEqual(vm.step, .height)
        XCTAssertEqual(vm.ageYears, 45)
    }

    func testHeightAcceptsImperialShorthand() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)
        vm.selectUnits(.imperial)
        vm.selectSex(.male)
        vm.ageInput = "35"; vm.submitAge()

        vm.heightInput = "5-11"
        vm.submitHeight()

        XCTAssertEqual(vm.step, .summary)
        XCTAssertEqual(vm.heightCm ?? 0, 180.34, accuracy: 0.01)
        XCTAssertEqual(vm.heightFeetInches?.feet, 5)
        XCTAssertEqual(vm.heightFeetInches?.inches, 11)
    }

    func testCommitSummaryPersistsAllFields() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)
        vm.selectUnits(.metric)
        vm.selectSex(.female)
        vm.ageInput = "29"; vm.submitAge()
        vm.heightInput = "170"; vm.submitHeight()

        XCTAssertTrue(vm.commitSummary())
        XCTAssertEqual(vm.step, .done)

        let saved = try XCTUnwrap(env.profile.current())
        XCTAssertEqual(saved.age, 29)
        XCTAssertEqual(saved.heightCm, 170, accuracy: 0.01)
        XCTAssertEqual(saved.sex, "female")
        XCTAssertEqual(saved.preferredUnits, "metric")
    }

    func testToggleSummarySexUpdatesTurnAnswer() throws {
        let env = try InMemoryEnvironment()
        let vm = ProfileFREViewModel(profile: env.profile)
        vm.selectUnits(.metric)
        vm.selectSex(.male)
        vm.ageInput = "35"; vm.submitAge()
        vm.heightInput = "180"; vm.submitHeight()

        vm.toggleSummarySex(.female)

        XCTAssertEqual(vm.sex, .female)
        let sexTurn = vm.turns.first(where: { $0.id == .sex })
        XCTAssertEqual(sexTurn?.answer, BiologicalSex.female.displayName)
    }
}
