import XCTest
@testable import ChewTheFat

@MainActor
final class GoalRepositoryProjectionTests: XCTestCase {
    func testAtGoalWithinTolerance() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.45,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
        let outcome = try env.goals.projectedGoal(currentWeightKg: 75.1)
        XCTAssertEqual(outcome, .atGoal)
    }

    func testLossProjectionReachesFutureDate() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.5,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
        let ref = Date(timeIntervalSince1970: 0)
        let outcome = try env.goals.projectedGoal(currentWeightKg: 85, reference: ref)
        guard case .projected(let date, let perDay) = outcome else {
            return XCTFail("expected projected outcome, got \(outcome)")
        }
        XCTAssertEqual(perDay, -0.5 / 7, accuracy: 0.0001)
        let days = (10 / (0.5 / 7))
        let expected = ref.addingTimeInterval(days * 86400)
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testGainProjection() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: 0.25,
            calorieTarget: 2800,
            proteinTargetG: 150,
            carbsTargetG: 300,
            fatTargetG: 90,
            idealWeightKg: 80
        ))
        let ref = Date(timeIntervalSince1970: 0)
        let outcome = try env.goals.projectedGoal(currentWeightKg: 72, reference: ref)
        guard case .projected(let date, let perDay) = outcome else {
            return XCTFail("expected projected outcome")
        }
        XCTAssertGreaterThan(perDay, 0)
        XCTAssertGreaterThan(date, ref)
    }

    func testWrongDirectionIsIndefinite() throws {
        let env = try InMemoryEnvironment()
        // User wants to reach 75kg from 85kg but weeklyChangeKg is positive (gain).
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: 0.3,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
        let outcome = try env.goals.projectedGoal(currentWeightKg: 85)
        XCTAssertEqual(outcome, .indefinite)
    }

    func testZeroRateIsIndefinite() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: 0,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
        let outcome = try env.goals.projectedGoal(currentWeightKg: 85)
        XCTAssertEqual(outcome, .indefinite)
    }

    func testNoGoalsIsIndefinite() throws {
        let env = try InMemoryEnvironment()
        let outcome = try env.goals.projectedGoal(currentWeightKg: 85)
        XCTAssertEqual(outcome, .indefinite)
    }

    func testNoCurrentWeightIsIndefinite() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.5,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
        let outcome = try env.goals.projectedGoal(currentWeightKg: nil)
        XCTAssertEqual(outcome, .indefinite)
    }
}
