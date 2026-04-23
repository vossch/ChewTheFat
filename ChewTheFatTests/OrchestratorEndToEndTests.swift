import XCTest
@testable import ChewTheFat

@MainActor
final class OrchestratorEndToEndTests: XCTestCase {
    /// M2 "Done when" #1: a turn that begins with "I weigh 185 lbs today" must
    /// dispatch `LogWeightTool` with valid arguments and persist a weight
    /// entry. The model is scripted to emit the expected tool call so this
    /// test covers the orchestrator → dispatcher → repository wiring without
    /// depending on Gemma actually running.
    func testWeightUtterance_dispatchesLogWeightTool_andPersistsEntry() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let session = try env.sessions.create(goal: .logWeight)

        // Convert 185 lb → kg = 185 * 0.453592 ≈ 83.91452
        let kg = 185.0 * 0.453592
        let toolCallId = "call_test_log_weight"
        let argsJSON = "{\"weightKg\":\(kg)}"

        let scripted = ScriptedModelClient(scripts: [
            // Turn 1: model issues a tool call (no user-visible text).
            [
                .toolCall(ToolCallRequest(
                    id: toolCallId,
                    identifier: .logWeight,
                    argumentsJSON: argsJSON
                )),
                .finished(.toolCall),
            ],
            // Turn 2: after the tool result is fed back, model produces a
            // confirmation reply.
            [
                .text("Logged 83.9 kg for today."),
                .finished(.stop),
            ],
        ])
        let orchestrator = env.makeOrchestrator(session: session, modelClient: scripted)

        var observedToolCalls: [ToolCallRequest] = []
        var observedOutcomes: [ToolCallOutcome] = []
        var observedWidgets: [WidgetIntent] = []
        var streamedText = ""

        for try await event in orchestrator.send(text: "I weigh 185 lbs today") {
            switch event {
            case .textChunk(let chunk): streamedText += chunk
            case .toolCallStarted(let call): observedToolCalls.append(call)
            case .toolCallFinished(let outcome): observedOutcomes.append(outcome)
            case .widget(let intent): observedWidgets.append(intent)
            case .completed: break
            }
        }

        XCTAssertEqual(observedToolCalls.count, 1)
        XCTAssertEqual(observedToolCalls.first?.identifier, .logWeight)
        XCTAssertEqual(observedOutcomes.count, 1)
        if case .failure(_, let err) = observedOutcomes[0] {
            XCTFail("LogWeightTool failed: \(err.localizedDescription)")
        }

        let latest = try env.weightLog.latest()
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.weightKg ?? 0, kg, accuracy: 0.01)

        // Tool emits a weightGraph widget on success — the orchestrator must
        // surface it.
        XCTAssertTrue(observedWidgets.contains(where: {
            if case .weightGraph = $0 { return true } else { return false }
        }), "Expected a weightGraph widget after LogWeightTool dispatch")

        // The model's confirmation reply must reach the user.
        XCTAssertTrue(streamedText.contains("Logged"), "streamedText: \(streamedText)")
    }
}
