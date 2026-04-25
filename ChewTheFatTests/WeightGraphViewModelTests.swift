import XCTest
@testable import ChewTheFat

@MainActor
final class WeightGraphViewModelTests: XCTestCase {
    func testTwoConsecutiveLogsReflectedInPoints() throws {
        let env = try InMemoryEnvironment()
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.5,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 80
        ))

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        _ = try env.weightLog.log(weightKg: 85.2, date: yesterday)
        _ = try env.weightLog.log(weightKg: 85.0, date: today)

        let start = calendar.date(byAdding: .day, value: -30, to: today)!
        let vm = WeightGraphViewModel(
            range: start...today,
            weightLog: env.weightLog,
            goals: env.goals
        )
        vm.reload()

        let past = vm.points.filter { !$0.isProjected }
        XCTAssertEqual(past.count, 2)
        XCTAssertEqual(past[0].weightKg, 85.2, accuracy: 0.01)
        XCTAssertEqual(past[1].weightKg, 85.0, accuracy: 0.01)
    }
}
