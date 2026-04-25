import XCTest
@testable import ChewTheFat

@MainActor
final class CoachingFlagTests: XCTestCase {
    private func saveGoals(
        _ env: InMemoryEnvironment,
        weeklyChangeKg: Double
    ) throws {
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: weeklyChangeKg,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
    }

    private func makeEntry(_ kg: Double, daysAgo: Int) -> WeightEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return WeightEntry(date: Calendar.current.startOfDay(for: date), weightKg: kg)
    }

    func testNormalDeltaReturnsNormal() throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env, weeklyChangeKg: -0.5)
        let prev = try env.weightLog.log(weightKg: 80, date: makeEntry(0, daysAgo: 2).date)
        let new = try env.weightLog.log(weightKg: 79.8, date: .now)
        let flag = try env.goals.coachingFlag(newEntry: new, history: [prev, new])
        XCTAssertEqual(flag, .normal)
    }

    func testRapidLossBeyondAbsoluteThreshold() throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env, weeklyChangeKg: -0.5)
        let prev = try env.weightLog.log(weightKg: 85, date: makeEntry(0, daysAgo: 1).date)
        let new = try env.weightLog.log(weightKg: 83, date: .now) // −2 kg in 1 day
        let flag = try env.goals.coachingFlag(newEntry: new, history: [prev, new])
        XCTAssertEqual(flag, .rapidLoss)
    }

    func testRapidGainBeyondRateMultiplier() throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env, weeklyChangeKg: -0.5) // expected per-day 0.071 kg
        let prev = try env.weightLog.log(weightKg: 80, date: makeEntry(0, daysAgo: 1).date)
        let new = try env.weightLog.log(weightKg: 80.4, date: .now) // +0.4/day > 3×0.071
        let flag = try env.goals.coachingFlag(newEntry: new, history: [prev, new])
        XCTAssertEqual(flag, .rapidGain)
    }

    func testPlateauAfterFourteenFlatDays() throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env, weeklyChangeKg: -0.5)
        let oldest = try env.weightLog.log(
            weightKg: 80.1,
            date: makeEntry(0, daysAgo: 15).date
        )
        let mid = try env.weightLog.log(
            weightKg: 80.0,
            date: makeEntry(0, daysAgo: 8).date
        )
        let new = try env.weightLog.log(weightKg: 80.0, date: .now)
        let flag = try env.goals.coachingFlag(
            newEntry: new,
            history: [oldest, mid, new]
        )
        XCTAssertEqual(flag, .plateau)
    }

    func testMaintenanceDoesNotPlateau() throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env, weeklyChangeKg: 0) // maintenance
        let oldest = try env.weightLog.log(
            weightKg: 80.0,
            date: makeEntry(0, daysAgo: 15).date
        )
        let new = try env.weightLog.log(weightKg: 80.0, date: .now)
        let flag = try env.goals.coachingFlag(newEntry: new, history: [oldest, new])
        XCTAssertEqual(flag, .normal)
    }
}
