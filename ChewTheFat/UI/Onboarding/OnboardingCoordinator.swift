import Foundation
import SwiftData

/// Drives the three-phase onboarding flow from US1 (see `Specs/spec.md` and
/// `Specs/implementation-plan.md` §M4):
///
///   1. `.eula` — static legal screen; Accept writes `UserProfile.eulaAcceptedAt`.
///   2. `.bootstrap` — `ModelBootstrapper` fetches weights on first launch.
///   3. `.chat` — a `SessionGoal.onboarding` session where the agent gathers
///      profile + goal fields conversationally. When its contract is satisfied
///      (checked via `SessionGoalEvaluator`) the coordinator advances to
///      `.ready` and the app swaps in the general chat surface.
///
/// The coordinator is idempotent and resume-safe: on relaunch it re-derives
/// the initial phase from persisted state so a killed app picks up where it
/// left off. Nothing is stored in UserDefaults — the single source of truth is
/// `UserProfile.eulaAcceptedAt`, `ModelBootstrapperProtocol.isReady`, and the
/// current `onboarding` session's goal contract.
@MainActor
@Observable
final class OnboardingCoordinator {
    enum Phase: Equatable {
        case loading
        case eula
        case bootstrap
        case chat(session: Session)
        case ready

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.eula, .eula), (.bootstrap, .bootstrap), (.ready, .ready):
                return true
            case let (.chat(a), .chat(b)):
                return a.id == b.id
            default:
                return false
            }
        }
    }

    private(set) var phase: Phase = .loading

    private let profile: ProfileRepository
    private let sessions: SessionRepository
    private let evaluator: SessionGoalEvaluator
    private let bootstrapper: ModelBootstrapperProtocol

    init(
        profile: ProfileRepository,
        sessions: SessionRepository,
        evaluator: SessionGoalEvaluator,
        bootstrapper: ModelBootstrapperProtocol
    ) {
        self.profile = profile
        self.sessions = sessions
        self.evaluator = evaluator
        self.bootstrapper = bootstrapper
    }

    /// Resolves the initial phase from persisted state. Safe to call multiple
    /// times (e.g. on relaunch, after scene restoration).
    func resolveInitialPhase() async {
        if (try? profile.current()?.eulaAcceptedAt) == nil {
            phase = .eula
            return
        }
        if await !bootstrapper.isReady {
            phase = .bootstrap
            return
        }
        if await onboardingContractSatisfied() {
            phase = .ready
            return
        }
        let session = (try? existingOnboardingSession()) ?? (try? sessions.create(goal: .onboarding))
        guard let session else {
            phase = .ready // degrade gracefully if persistence is unavailable
            return
        }
        phase = .chat(session: session)
    }

    func acceptEULA() {
        do {
            try profile.acceptEULA()
        } catch {
            return
        }
        Task { await advanceFromEULA() }
    }

    func bootstrapDidComplete() {
        Task { await advanceFromBootstrap() }
    }

    /// Called by the chat surface after each orchestrator turn. If the
    /// onboarding contract is now satisfied, the coordinator advances to
    /// `.ready`; otherwise the chat phase remains active.
    func recheckOnboardingCompletion() async {
        guard case .chat = phase else { return }
        if await onboardingContractSatisfied() {
            phase = .ready
        }
    }

    // MARK: - Private

    private func advanceFromEULA() async {
        if await !bootstrapper.isReady {
            phase = .bootstrap
            return
        }
        await advanceFromBootstrap()
    }

    private func advanceFromBootstrap() async {
        if await onboardingContractSatisfied() {
            phase = .ready
            return
        }
        let session: Session
        do {
            session = try existingOnboardingSession() ?? (try sessions.create(goal: .onboarding))
        } catch {
            phase = .ready
            return
        }
        phase = .chat(session: session)
    }

    private func onboardingContractSatisfied() async -> Bool {
        let contract = SessionGoalContract.contract(for: .onboarding)
        let progress = await evaluator.evaluate(contract)
        return progress.satisfied
    }

    private func existingOnboardingSession() throws -> Session? {
        try sessions.list(limit: 20).first { $0.goal == SessionGoal.onboarding.rawValue }
    }
}
