import XCTest
@testable import ChewTheFat

@MainActor
final class SessionStateManagerTests: XCTestCase {
    /// M2 "Done when" #2: an `.onboarding` session refuses to switch to
    /// `.logWeight` while its contract is unsatisfied, and writes a
    /// system-authored note describing the gap instead.
    func testOnboardingRejectsLogWeightTransition_andEmitsSystemNote() async throws {
        let env = try InMemoryEnvironment()
        let onboardingSession = try env.sessions.create(goal: .onboarding)
        let manager = SessionStateManager(
            session: onboardingSession,
            evaluator: env.evaluator,
            sessions: env.sessions
        )

        let outcome = try await manager.startSession(goal: .logWeight)

        guard case .redirected(let session, let note) = outcome else {
            return XCTFail("Expected .redirected, got \(outcome)")
        }
        XCTAssertEqual(session.id, onboardingSession.id)
        XCTAssertTrue(note.contains("onboarding incomplete"), "note: \(note)")
        XCTAssertEqual(manager.session.id, onboardingSession.id, "active session must not change")
        XCTAssertEqual(manager.goal, .onboarding)

        let systemNotes = onboardingSession.messages.filter { $0.author == "system" }
        XCTAssertEqual(systemNotes.count, 1)
        XCTAssertEqual(systemNotes.first?.textContent, note)
    }

    func testCompletedOnboarding_allowsLogWeightTransition() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let onboardingSession = try env.sessions.create(goal: .onboarding)
        let manager = SessionStateManager(
            session: onboardingSession,
            evaluator: env.evaluator,
            sessions: env.sessions
        )

        let outcome = try await manager.startSession(goal: .logWeight)

        guard case .started(let newSession) = outcome else {
            return XCTFail("Expected .started, got \(outcome)")
        }
        XCTAssertEqual(SessionGoal(rawValue: newSession.goal), .logWeight)
        XCTAssertNotEqual(newSession.id, onboardingSession.id)
        XCTAssertEqual(manager.session.id, newSession.id)
    }
}
