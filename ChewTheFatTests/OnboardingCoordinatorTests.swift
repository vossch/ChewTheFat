import XCTest
@testable import ChewTheFat

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testFreshInstallStartsAtEULA() async throws {
        let env = try InMemoryEnvironment()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .eula)
    }

    func testEULAAcceptedButModelNotReadyAdvancesToBootstrap() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: StubBootstrapper(isReady: false)
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .bootstrap)
    }

    func testEULAAndModelReadyAdvancesToChat() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        if case .chat(let session) = coordinator.phase {
            XCTAssertEqual(session.goal, SessionGoal.onboarding.rawValue)
        } else {
            XCTFail("expected chat phase, got \(coordinator.phase)")
        }
    }

    func testFullyOnboardedSkipsToReady() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .ready)
    }

    func testResumeReusesExistingOnboardingSession() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        let first = try env.sessions.create(goal: .onboarding)

        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        guard case .chat(let session) = coordinator.phase else {
            return XCTFail("expected chat phase")
        }
        XCTAssertEqual(session.id, first.id)
    }

    func testRecheckAdvancesWhenContractSatisfied() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()

        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            sessions: env.sessions,
            evaluator: env.evaluator,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        guard case .chat = coordinator.phase else {
            return XCTFail("expected chat phase")
        }

        // Fill in the remaining profile + goal fields on the EULA-accepted
        // profile (rather than inserting a second UserProfile).
        let existing = try XCTUnwrap(env.profile.current())
        existing.age = 35
        existing.heightCm = 175
        existing.sex = "other"
        existing.preferredUnits = "metric"
        existing.activityLevel = "moderate"
        try env.profile.save(existing)
        try env.goals.save(UserGoals(
            method: "manual",
            weeklyChangeKg: -0.45,
            calorieTarget: 2000,
            proteinTargetG: 150,
            carbsTargetG: 200,
            fatTargetG: 70,
            idealWeightKg: 75
        ))

        await coordinator.recheckOnboardingCompletion()
        XCTAssertEqual(coordinator.phase, .ready)
    }
}

private final class StubBootstrapper: ModelBootstrapperProtocol, @unchecked Sendable {
    let modelId = "stub"
    private let _isReady: Bool

    init(isReady: Bool) { self._isReady = isReady }

    var isReady: Bool { _isReady }

    func progress() -> AsyncStream<BootstrapProgress> {
        AsyncStream { $0.finish() }
    }

    func fetch() async throws {}
    func cancel() async {}
}
