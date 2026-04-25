import XCTest
@testable import ChewTheFat

@MainActor
final class LogWeightToolTests: XCTestCase {
    private func saveGoals(_ env: InMemoryEnvironment) throws {
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.5,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))
    }

    private func decodeOutput(_ result: ToolResult) throws -> [String: Any] {
        let obj = try JSONSerialization.jsonObject(with: result.payload)
        return (obj as? [String: Any]) ?? [:]
    }

    func testLogReturnsWeightGraphWidget() async throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env)
        let tool = LogWeightTool(weightLog: env.weightLog, goals: env.goals)
        let result = try await tool.invoke(ToolArguments(json: #"{"weightKg": 80.0}"#))
        guard case .weightGraph = result.widget else {
            XCTFail("expected weightGraph widget, got \(String(describing: result.widget))")
            return
        }
    }

    func testNormalDeltaReportsNormalFlag() async throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env)
        _ = try env.weightLog.log(
            weightKg: 80,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        let tool = LogWeightTool(weightLog: env.weightLog, goals: env.goals)
        let result = try await tool.invoke(ToolArguments(json: #"{"weightKg": 79.9}"#))
        let obj = try decodeOutput(result)
        XCTAssertEqual(obj["coachingFlag"] as? String, CoachingFlag.normal.rawValue)
    }

    func testRapidLossFlagsTheEntry() async throws {
        let env = try InMemoryEnvironment()
        try saveGoals(env)
        _ = try env.weightLog.log(
            weightKg: 85,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        let tool = LogWeightTool(weightLog: env.weightLog, goals: env.goals)
        let result = try await tool.invoke(ToolArguments(json: #"{"weightKg": 82.5}"#))
        let obj = try decodeOutput(result)
        XCTAssertEqual(obj["coachingFlag"] as? String, CoachingFlag.rapidLoss.rawValue)
    }
}
