import XCTest
@testable import ChewTheFat

final class CalorieBudgetEstimatorTests: XCTestCase {
    func testMaleBMRMifflinMatchesSpec() {
        // Canonical example: 35yo male, 180 cm, 80 kg.
        // BMR = 10·80 + 6.25·180 − 5·35 + 5 = 800 + 1125 − 175 + 5 = 1755
        let bmr = CalorieBudgetEstimator.bmr(
            sex: .male, ageYears: 35, heightCm: 180, weightKg: 80
        )
        XCTAssertEqual(bmr, 1755, accuracy: 0.01)
    }

    func testFemaleBMRMifflinMatchesSpec() {
        // 30yo female, 165 cm, 60 kg.
        // BMR = 10·60 + 6.25·165 − 5·30 − 161 = 600 + 1031.25 − 150 − 161 = 1320.25
        let bmr = CalorieBudgetEstimator.bmr(
            sex: .female, ageYears: 30, heightCm: 165, weightKg: 60
        )
        XCTAssertEqual(bmr, 1320.25, accuracy: 0.01)
    }

    func testTDEEAppliesActivityMultiplier() {
        let bmr = 1500.0
        XCTAssertEqual(CalorieBudgetEstimator.tdee(bmr: bmr, activity: .sedentary), 1800)
        XCTAssertEqual(CalorieBudgetEstimator.tdee(bmr: bmr, activity: .athlete), 2850)
    }

    func testCalorieTargetAppliesWeeklyDeficit() {
        // Male, 35yo, 180cm, 80kg, moderate activity, target −0.45 kg/week.
        // BMR 1755 × 1.55 = 2720.25
        // Weekly deficit kcal = 0.45 × 7700 / 7 = 495 kcal/day
        // Expected target ≈ 2720.25 − 495 = 2225.25 → rounded 2225
        let target = CalorieBudgetEstimator.calorieTarget(
            sex: .male,
            ageYears: 35,
            heightCm: 180,
            weightKg: 80,
            activity: .moderate,
            weeklyChangeKg: -0.45
        )
        XCTAssertEqual(target, 2225)
    }

    func testMaintenanceTargetEqualsTDEE() {
        let target = CalorieBudgetEstimator.calorieTarget(
            sex: .male,
            ageYears: 35,
            heightCm: 180,
            weightKg: 80,
            activity: .moderate,
            weeklyChangeKg: 0
        )
        // TDEE = 1755 * 1.55 = 2720.25 → 2720
        XCTAssertEqual(target, 2720)
    }

    func testDefaultMacrosSumToCalorieTarget() {
        let target = 2000
        let macros = CalorieBudgetEstimator.defaultMacros(calorieTarget: target)
        // 30/40/30 split with 4/4/9 kcal per gram → 150/200/66.67 g
        XCTAssertEqual(macros.proteinG, 150, accuracy: 0.5)
        XCTAssertEqual(macros.carbsG, 200, accuracy: 0.5)
        XCTAssertEqual(macros.fatG, 66.67, accuracy: 0.5)
        let reconstituted = macros.proteinG * 4 + macros.carbsG * 4 + macros.fatG * 9
        XCTAssertEqual(reconstituted, Double(target), accuracy: 1.0)
    }

    func testDefaultMacrosZeroCaloriesReturnsZero() {
        let macros = CalorieBudgetEstimator.defaultMacros(calorieTarget: 0)
        XCTAssertEqual(macros.proteinG, 0)
        XCTAssertEqual(macros.carbsG, 0)
        XCTAssertEqual(macros.fatG, 0)
    }

    func testBiologicalSexFromStoredValue() {
        XCTAssertEqual(BiologicalSex(storedValue: "male"), .male)
        XCTAssertEqual(BiologicalSex(storedValue: "FEMALE"), .female)
        XCTAssertNil(BiologicalSex(storedValue: nil))
        XCTAssertNil(BiologicalSex(storedValue: ""))
        XCTAssertNil(BiologicalSex(storedValue: "other"))
    }
}
