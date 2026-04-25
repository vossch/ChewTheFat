import XCTest
import SwiftData
@testable import ChewTheFat

@MainActor
final class AppEnvironmentSessionSeedTests: XCTestCase {
    private func makeEnv() throws -> AppEnvironment {
        try AppEnvironment.testing()
    }

    func testLogWeightSessionSeededWithPromptWidget() throws {
        let env = try makeEnv()
        _ = try env.weightLog.log(weightKg: 88, date: .now)

        let session = try env.createSession(goal: .logWeight)
        XCTAssertEqual(session.messages.count, 1)
        let message = try XCTUnwrap(session.messages.first)
        XCTAssertEqual(message.author, "assistant")
        XCTAssertEqual(message.textContent, "Time to weigh in. Where are you today?")
        XCTAssertEqual(message.widgets.count, 1)
        let row = try XCTUnwrap(message.widgets.first)
        XCTAssertEqual(row.type, "weightLogPrompt")
        let decoded = try XCTUnwrap(WidgetIntentDecoder.decode(row))
        guard case .weightLogPrompt(let payload) = decoded else {
            return XCTFail("expected weightLogPrompt intent")
        }
        XCTAssertEqual(payload.suggestionsKg.count, 5)
        XCTAssertEqual(payload.lastEntryKg ?? 0, 88, accuracy: 0.01)
    }

    func testGeneralSessionIsNotSeeded() throws {
        let env = try makeEnv()
        let session = try env.createSession(goal: .general)
        XCTAssertTrue(session.messages.isEmpty)
    }

    func testLogMealSessionIsNotSeeded() throws {
        let env = try makeEnv()
        let session = try env.createSession(goal: .logMeal)
        XCTAssertTrue(session.messages.isEmpty)
    }
}
