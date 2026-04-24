import Foundation

@MainActor
protocol OrchestratorProtocol {
    func send(text: String) -> AsyncThrowingStream<TurnEvent, Error>

    /// Runs an opening turn with no user input. Used by onboarding to let the
    /// model author the first message itself, steered by the session goal and
    /// knowledge context rather than a hard-coded greeting. No-op on sessions
    /// that already have messages.
    func kickoff() -> AsyncThrowingStream<TurnEvent, Error>
}
