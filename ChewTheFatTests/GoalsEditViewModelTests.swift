import XCTest
@testable import ChewTheFat

@MainActor
final class GoalsEditViewModelTests: XCTestCase {
    func testDefaultsSumToHundred() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)
        XCTAssertEqual(Int((vm.proteinPct + vm.carbsPct + vm.fatPct).rounded()), 100)
    }

    func testAdjustProteinRebalancesOthers() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)

        vm.adjust(.protein, to: 50)
        XCTAssertEqual(vm.proteinPct, 50, accuracy: 0.01)
        XCTAssertEqual(Int((vm.proteinPct + vm.carbsPct + vm.fatPct).rounded()), 100)
    }

    func testAdjustPinsAtHundred() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)

        vm.adjust(.fat, to: 100)
        XCTAssertEqual(vm.fatPct, 100)
        XCTAssertEqual(vm.proteinPct, 0)
        XCTAssertEqual(vm.carbsPct, 0)
        XCTAssertEqual(Int((vm.proteinPct + vm.carbsPct + vm.fatPct).rounded()), 100)
    }

    func testAdjustFromZeroSplitsEvenly() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)

        // Drive others to zero, then drag protein back down — remaining must
        // redistribute evenly between carbs and fat (no division-by-zero).
        vm.adjust(.protein, to: 100)
        vm.adjust(.protein, to: 60)
        XCTAssertEqual(vm.proteinPct, 60)
        XCTAssertEqual(vm.carbsPct, 20, accuracy: 0.01)
        XCTAssertEqual(vm.fatPct, 20, accuracy: 0.01)
        XCTAssertEqual(Int((vm.proteinPct + vm.carbsPct + vm.fatPct).rounded()), 100)
    }

    func testAdjustRejectsValuesAboveHundred() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)

        vm.adjust(.carbs, to: 150)
        XCTAssertEqual(vm.carbsPct, 100)
        XCTAssertEqual(Int((vm.proteinPct + vm.carbsPct + vm.fatPct).rounded()), 100)
    }

    func testSavePersistsGrams() throws {
        let env = try InMemoryEnvironment()
        let vm = GoalsEditViewModel(goals: env.goals, profile: env.profile)
        vm.method = .manual
        vm.calorieTarget = 2000
        vm.weeklyChangeKg = -0.45
        vm.idealWeightInput = "75"
        vm.adjust(.protein, to: 30)
        vm.adjust(.carbs, to: 40)
        vm.adjust(.fat, to: 30)

        XCTAssertTrue(vm.save())

        let saved = try XCTUnwrap(env.goals.current())
        XCTAssertEqual(saved.calorieTarget, 2000)
        XCTAssertEqual(saved.proteinTargetG, 150, accuracy: 0.5) // 30% of 2000 / 4
        XCTAssertEqual(saved.carbsTargetG, 200, accuracy: 0.5)   // 40% of 2000 / 4
        XCTAssertEqual(saved.fatTargetG, 200.0 / 3.0, accuracy: 0.5) // 30% of 2000 / 9
        XCTAssertEqual(saved.idealWeightKg, 75)
        XCTAssertTrue(saved.calorieIsManual)
        XCTAssertTrue(saved.macrosAreManual)
    }
}
