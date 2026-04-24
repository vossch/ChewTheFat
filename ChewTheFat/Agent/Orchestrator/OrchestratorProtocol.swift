import Foundation

@MainActor
protocol OrchestratorProtocol {
    func send(text: String) -> AsyncThrowingStream<TurnEvent, Error>
}
