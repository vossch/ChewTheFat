import XCTest
@testable import ChewTheFat

@MainActor
final class GoalProgressContextSourceTests: XCTestCase {
    /// M2 "Done when" #3: `GoalProgressContextSource` injects an up-to-date
    /// checklist that survives `ContextAssembler.assemble` and lands in the
    /// `included` list of the resulting `AssembledContext`.
    func testGoalProgress_isInjected_intoAssembledContext() async throws {
        let env = try InMemoryEnvironment()
        let source = GoalProgressContextSource(evaluator: env.evaluator)
        let request = ContextRequest(sessionId: UUID(), goal: .onboarding)

        let fragments = await source.contribute(for: request)
        XCTAssertEqual(fragments.count, 1)
        let fragment = try XCTUnwrap(fragments.first)
        XCTAssertEqual(fragment.label, "GoalProgress")
        XCTAssertEqual(fragment.priority, .critical)
        XCTAssertTrue(fragment.body.contains("Session goal: onboarding"))
        XCTAssertTrue(fragment.body.contains("MISSING"), "Empty profile should report missing fields. Body: \(fragment.body)")

        let assembler = ContextAssembler()
        let assembled = await assembler.assemble(fragments: fragments)
        XCTAssertTrue(assembled.included.contains("GoalProgress"))
        XCTAssertTrue(assembled.systemPrompt.contains("Session goal: onboarding"))
        XCTAssertTrue(assembled.systemPrompt.contains("MISSING"))
    }

    func testGoalProgress_reflectsCompletedOnboarding() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let source = GoalProgressContextSource(evaluator: env.evaluator)

        let fragments = await source.contribute(for: ContextRequest(sessionId: UUID(), goal: .onboarding))
        let body = try XCTUnwrap(fragments.first?.body)

        XCTAssertTrue(body.contains("Satisfied: true"), "Body: \(body)")
        XCTAssertFalse(body.contains("MISSING"), "Body: \(body)")
    }
}
