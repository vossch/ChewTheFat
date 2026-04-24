import XCTest
@testable import ChewTheFat

@MainActor
final class GoalsFREViewModelTests: XCTestCase {
    private func makeVM(
        _ env: InMemoryEnvironment,
        configureProfile: Bool = true
    ) throws -> GoalsFREViewModel {
        if configureProfile {
            let p = try env.profile.current() ?? UserProfile(
                age: 35,
                heightCm: 180,
                sex: "male",
                preferredUnits: "metric",
                activityLevel: ""
            )
            p.age = 35
            p.heightCm = 180
            p.sex = "male"
            p.preferredUnits = "metric"
            try env.profile.save(p)
        }
        return GoalsFREViewModel(
            goals: env.goals,
            profile: env.profile,
            weightLog: env.weightLog
        )
    }

    func testStartsOnWeeklyChangeStep() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        XCTAssertEqual(vm.step, .weeklyChange)
        XCTAssertEqual(vm.turns.first?.id, .weeklyChange)
    }

    func testWeeklyChangeThenActivityThenCurrentWeight() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)

        let losePreset = GoalsFREViewModel.weeklyChangeOptions[1] // -1 lb/wk
        vm.selectWeeklyChange(losePreset)
        XCTAssertEqual(vm.step, .activity)

        vm.selectActivity(.moderate)
        XCTAssertEqual(vm.step, .currentWeight)
        XCTAssertEqual(vm.activity, .moderate)
    }

    func testCurrentWeightUsesPreferredUnits() throws {
        let env = try InMemoryEnvironment()
        // imperial profile → input interpreted as lb
        try env.profile.save(UserProfile(
            age: 35,
            heightCm: 180,
            sex: "male",
            preferredUnits: "imperial",
            activityLevel: ""
        ))
        let vm = GoalsFREViewModel(
            goals: env.goals,
            profile: env.profile,
            weightLog: env.weightLog
        )
        vm.selectWeeklyChange(GoalsFREViewModel.weeklyChangeOptions[0])
        vm.selectActivity(.light)
        vm.currentWeightInput = "200"
        vm.submitCurrentWeight()

        // 200 lb = 90.72 kg
        XCTAssertEqual(vm.currentWeightKg ?? 0, 90.72, accuracy: 0.01)
        XCTAssertEqual(vm.step, .idealWeight)
    }

    func testIdealWeightSuggestionsDeriveFromHeight() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        // Profile height 180 cm → 1.8 m, BMI 22 → 71.28 kg (among others).
        let suggestions = vm.idealWeightSuggestions
        XCTAssertEqual(suggestions.count, 4)
        XCTAssertTrue(suggestions.allSatisfy { $0.kg > 50 && $0.kg < 100 })
    }

    func testAutoModeCaloriesDerivedFromEstimator() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        vm.selectWeeklyChange(GoalsFREViewModel.weeklyChangeOptions.last!) // +0.5 lb/wk
        vm.selectActivity(.moderate)
        vm.currentWeightInput = "80"
        vm.submitCurrentWeight()

        let expected = CalorieBudgetEstimator.calorieTarget(
            sex: .male,
            ageYears: 35,
            heightCm: 180,
            weightKg: 80,
            activity: .moderate,
            weeklyChangeKg: GoalsFREViewModel.weeklyChangeOptions.last!.kgPerWeek
        )
        XCTAssertEqual(vm.summaryCalories, expected)
    }

    func testManualModeMacrosSumToHundred() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        vm.method = .manual
        vm.manualCalories = 2200

        vm.adjustMacro(.protein, to: 40)
        let sum = vm.summaryMacros.proteinG * 4 + vm.summaryMacros.carbsG * 4 + vm.summaryMacros.fatG * 9
        XCTAssertEqual(sum, 2200, accuracy: 1.0)
    }

    func testCommitPersistsGoalsProfileActivityAndLogsWeight() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        vm.selectWeeklyChange(GoalsFREViewModel.weeklyChangeOptions[1])
        vm.selectActivity(.heavy)
        vm.currentWeightInput = "82"; vm.submitCurrentWeight()
        let suggestion = vm.idealWeightSuggestions.first!
        vm.selectIdealWeight(suggestion)

        XCTAssertTrue(vm.commitSummary())
        XCTAssertEqual(vm.step, .done)

        let saved = try XCTUnwrap(env.goals.current())
        XCTAssertGreaterThan(saved.calorieTarget, 0)
        XCTAssertEqual(saved.idealWeightKg ?? 0, suggestion.kg, accuracy: 0.01)
        XCTAssertEqual(saved.weeklyChangeKg,
                       GoalsFREViewModel.weeklyChangeOptions[1].kgPerWeek,
                       accuracy: 0.0001)

        let profile = try XCTUnwrap(env.profile.current())
        XCTAssertEqual(profile.activityLevel, ActivityLevel.heavy.rawValue)

        let weight = try XCTUnwrap(env.weightLog.latest())
        XCTAssertEqual(weight.weightKg, 82, accuracy: 0.01)
    }

    func testProjectedGoalDateWhenDeficitHeadsTowardGoal() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        vm.selectWeeklyChange(GoalsFREViewModel.weeklyChangeOptions[1]) // -1 lb/wk
        vm.selectActivity(.moderate)
        vm.currentWeightInput = "90"; vm.submitCurrentWeight()
        vm.idealWeightInput = "80"; vm.submitCustomIdealWeight()

        XCTAssertNotNil(vm.projectedGoalDate)
    }

    func testProjectedGoalDateNilWhenMaintaining() throws {
        let env = try InMemoryEnvironment()
        let vm = try makeVM(env)
        vm.selectWeeklyChange(GoalsFREViewModel.weeklyChangeOptions[3]) // maintenance
        vm.selectActivity(.moderate)
        vm.currentWeightInput = "80"; vm.submitCurrentWeight()
        vm.idealWeightInput = "75"; vm.submitCustomIdealWeight()

        XCTAssertNil(vm.projectedGoalDate)
    }
}
