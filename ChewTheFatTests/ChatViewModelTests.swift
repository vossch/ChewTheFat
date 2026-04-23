import XCTest
@testable import ChewTheFat

@MainActor
final class ChatViewModelTests: XCTestCase {
    /// `.textChunk` events must coalesce into a single assistant bubble,
    /// not spawn one per chunk.
    func testTextChunks_coalesceIntoSingleAssistantBubble() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let session = try env.sessions.create(goal: .general)

        let scripted = ScriptedModelClient(scripts: [
            [
                .text("Hello"),
                .text(", "),
                .text("world."),
                .finished(.stop),
            ]
        ])
        let orchestrator = env.makeOrchestrator(session: session, modelClient: scripted)
        let vm = ChatViewModel(orchestrator: orchestrator, session: session)

        vm.send("hi")
        try await waitUntil(timeout: 2.0) { vm.status == .idle }

        let assistantBubbles = vm.messages.compactMap { msg -> String? in
            if case .text(_, .assistant, let body) = msg { return body }
            return nil
        }
        XCTAssertEqual(assistantBubbles.count, 1, "all chunks should coalesce into one bubble")
        XCTAssertEqual(assistantBubbles.first, "Hello, world.")
    }

    /// Tool-call lifecycle events are invisible per constitution P4 —
    /// neither the request nor the outcome should appear in the display list.
    func testToolCallEvents_produceNoUserVisibleArtifact() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let session = try env.sessions.create(goal: .logWeight)

        let toolCallId = "call_chatvm_tool"
        let argsJSON = "{\"weightKg\":80.0}"
        let scripted = ScriptedModelClient(scripts: [
            [
                .toolCall(ToolCallRequest(
                    id: toolCallId,
                    identifier: .logWeight,
                    argumentsJSON: argsJSON
                )),
                .finished(.toolCall),
            ],
            [
                .text("Logged."),
                .finished(.stop),
            ],
        ])
        let orchestrator = env.makeOrchestrator(session: session, modelClient: scripted)
        let vm = ChatViewModel(orchestrator: orchestrator, session: session)

        vm.send("I weigh 80 kg")
        try await waitUntil(timeout: 2.0) { vm.status == .idle }

        for message in vm.messages {
            if case .text(_, _, let body) = message {
                XCTAssertFalse(body.lowercased().contains("tool"), "no tool vocabulary allowed: \(body)")
                XCTAssertFalse(body.contains(toolCallId), "no tool ids allowed: \(body)")
            }
        }
    }

    /// Widget emissions must land as `.widget` display-messages that render
    /// inline with assistant text.
    func testWidgetEmission_appendsWidgetDisplayMessage() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let session = try env.sessions.create(goal: .logWeight)

        let toolCallId = "call_chatvm_widget"
        let argsJSON = "{\"weightKg\":80.0}"
        let scripted = ScriptedModelClient(scripts: [
            [
                .toolCall(ToolCallRequest(
                    id: toolCallId,
                    identifier: .logWeight,
                    argumentsJSON: argsJSON
                )),
                .finished(.toolCall),
            ],
            [
                .text("Logged."),
                .finished(.stop),
            ],
        ])
        let orchestrator = env.makeOrchestrator(session: session, modelClient: scripted)
        let vm = ChatViewModel(orchestrator: orchestrator, session: session)

        vm.send("I weigh 80 kg")
        try await waitUntil(timeout: 2.0) { vm.status == .idle }

        let widgetEntry = vm.messages.first(where: {
            if case .widget = $0 { return true } else { return false }
        })
        XCTAssertNotNil(widgetEntry, "expected a widget display-message")
    }

    private func waitUntil(
        timeout: TimeInterval,
        _ predicate: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline { throw Failure.timedOut }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private enum Failure: Error { case timedOut }
}
