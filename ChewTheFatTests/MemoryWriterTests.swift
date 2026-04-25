import XCTest
@testable import ChewTheFat

@MainActor
final class MemoryWriterTests: XCTestCase {
    func testExplicitRememberCueIsCaptured() throws {
        let env = try InMemoryEnvironment()
        let writer = MemoryWriter(memory: env.memory)
        writer.observe(userText: "remember that I prefer oat milk", toolOutcomes: [])
        let entries = try env.memory.list()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.content, "I prefer oat milk")
        XCTAssertEqual(entries.first?.category, "userNote")
    }

    func testNoteCueIsCaptured() throws {
        let env = try InMemoryEnvironment()
        let writer = MemoryWriter(memory: env.memory)
        writer.observe(userText: "FYI travel next week", toolOutcomes: [])
        let entries = try env.memory.list()
        XCTAssertEqual(entries.first?.content, "travel next week")
    }

    func testPlainChatTextDoesNotPersist() throws {
        let env = try InMemoryEnvironment()
        let writer = MemoryWriter(memory: env.memory)
        writer.observe(userText: "what's the weather", toolOutcomes: [])
        let entries = try env.memory.list()
        XCTAssertTrue(entries.isEmpty)
    }

    func testWeightFlagAnomalyIsRecorded() throws {
        let env = try InMemoryEnvironment()
        let writer = MemoryWriter(memory: env.memory)

        let payload: [String: Any] = [
            "coachingFlag": "rapidLoss",
            "weightKg": 78.5
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let call = ToolCallRequest(identifier: .logWeight, argumentsJSON: "{}")
        let result = ToolResult(payload: data)
        writer.observe(userText: nil, toolOutcomes: [.success(call: call, result: result)])

        let entries = try env.memory.list()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.category, "weightFlag")
        XCTAssertTrue(entries.first?.content.contains("rapidLoss") == true)
    }

    func testNormalWeightFlagIsIgnored() throws {
        let env = try InMemoryEnvironment()
        let writer = MemoryWriter(memory: env.memory)
        let payload: [String: Any] = ["coachingFlag": "normal", "weightKg": 80.0]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let call = ToolCallRequest(identifier: .logWeight, argumentsJSON: "{}")
        let result = ToolResult(payload: data)
        writer.observe(userText: nil, toolOutcomes: [.success(call: call, result: result)])
        XCTAssertTrue(try env.memory.list().isEmpty)
    }
}
