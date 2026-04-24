import Foundation

/// Drives the scripted First Run Experience:
///
///   1. `.eula`          — static legal screen; Accept writes `UserProfile.eulaAcceptedAt`.
///   2. `.profileFRE`    — scripted units/sex/age/height capture (see `ProfileFREView`).
///   3. `.goalsFRE`      — scripted weekly-change/activity/weight/ideal-weight capture.
///   4. `.downloadingAI` — blocks only if the MLX weight fetch is still in flight
///                         after the user finishes setup; otherwise skipped.
///   5. `.ready`         — main app.
///
/// Model weights download concurrently with `.profileFRE` and `.goalsFRE` so
/// the user is never staring at a spinner while their profile fills itself in.
/// Nothing is tracked in `UserDefaults`: resume-on-relaunch is derived entirely
/// from `UserProfile`, `UserGoals`, and `ModelBootstrapperProtocol.isReady`.
///
/// The old conversational onboarding path (a SessionGoal.onboarding session
/// driven by the LLM) is gone — the scripted FRE captures the same fields
/// without requiring the model to be loaded.
@MainActor
@Observable
final class OnboardingCoordinator {
    enum Phase: Equatable, Hashable {
        case loading
        case eula
        case profileFRE
        case goalsFRE
        case downloadingAI
        case ready
    }

    private(set) var phase: Phase = .loading

    private let profile: ProfileRepository
    private let goals: GoalRepository
    private let bootstrapper: ModelBootstrapperProtocol

    init(
        profile: ProfileRepository,
        goals: GoalRepository,
        bootstrapper: ModelBootstrapperProtocol
    ) {
        self.profile = profile
        self.goals = goals
        self.bootstrapper = bootstrapper
    }

    /// Resolves the initial phase from persisted state. Safe to call multiple
    /// times (e.g. on relaunch, after scene restoration).
    func resolveInitialPhase() async {
        let current = try? profile.current()
        if current?.eulaAcceptedAt == nil {
            phase = .eula
            return
        }
        if !isProfileComplete(current) {
            phase = .profileFRE
            startBootstrapIfNeeded()
            return
        }
        if !isGoalsComplete() {
            phase = .goalsFRE
            startBootstrapIfNeeded()
            return
        }
        if await !bootstrapper.isReady {
            phase = .downloadingAI
            return
        }
        phase = .ready
    }

    func acceptEULA() {
        do {
            try profile.acceptEULA()
        } catch {
            return
        }
        startBootstrapIfNeeded()
        phase = .profileFRE
    }

    /// Invoked when the Profile FRE commits its summary. Transitions to the
    /// Goals FRE regardless of download state — the two run in parallel.
    func profileFREDidComplete() {
        phase = .goalsFRE
    }

    /// Invoked when the Goals FRE commits. If the model is already on disk we
    /// jump straight to `.ready`; otherwise we surface the download waiting
    /// screen.
    func goalsFREDidComplete() {
        Task {
            if await bootstrapper.isReady {
                phase = .ready
            } else {
                phase = .downloadingAI
            }
        }
    }

    func downloadDidComplete() {
        phase = .ready
    }

    // MARK: - Private

    private func isProfileComplete(_ profile: UserProfile?) -> Bool {
        guard let profile else { return false }
        return profile.age > 0 && profile.heightCm > 0 && !profile.sex.isEmpty
    }

    private func isGoalsComplete() -> Bool {
        guard let row = try? goals.current() else { return false }
        return row.calorieTarget > 0 && row.idealWeightKg != nil
    }

    /// Kicks off the background weight fetch exactly once. `ModelBootstrapper`
    /// coalesces concurrent callers, so redundant calls are safe.
    private func startBootstrapIfNeeded() {
        let bootstrapper = self.bootstrapper
        Task.detached {
            if await bootstrapper.isReady { return }
            try? await bootstrapper.fetch()
        }
    }
}
