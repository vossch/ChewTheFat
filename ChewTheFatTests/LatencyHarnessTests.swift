import XCTest
@testable import ChewTheFat

/// SC-002a latency target: first token from the model ≤ 3 s on an A15+ device.
///
/// This harness is **skipped by default**. It only runs end-to-end when the
/// `MLX_LATENCY_TEST` environment variable is set on a real A15+ device, and
/// only succeeds if the model weights have already been bootstrapped (so the
/// test isn't measuring HuggingFace download time).
@MainActor
final class LatencyHarnessTests: XCTestCase {
    func testFirstToken_arrivesUnder3s_onA15PlusDevice() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["MLX_LATENCY_TEST"] == "1",
            "Set MLX_LATENCY_TEST=1 to run on a real A15+ device with bootstrapped weights."
        )

        #if targetEnvironment(simulator)
        throw XCTSkip("Latency target is only meaningful on real Apple silicon devices.")
        #else
        let bootstrapper = try ModelBootstrapper()
        let isReady = await bootstrapper.isReady
        try XCTSkipUnless(isReady, "Bootstrap weights first; this test does not measure download time.")

        let client = try MLXModelClient()
        try await client.warmUp()

        let request = ModelRequest(
            systemPrompt: "You are a helpful assistant.",
            messages: [ChatMessage(role: .user, content: "Say hi.")]
        )

        let start = ContinuousClock().now
        var firstTokenAt: ContinuousClock.Instant?

        for try await event in client.stream(request) {
            if case .text = event {
                firstTokenAt = ContinuousClock().now
                break
            }
        }

        let unwrapped = try XCTUnwrap(firstTokenAt, "Stream finished without emitting any text token.")
        let elapsed = unwrapped - start
        XCTAssertLessThanOrEqual(elapsed, .seconds(3), "First-token latency \(elapsed) exceeded SC-002a budget")
        #endif
    }
}
