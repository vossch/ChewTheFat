import XCTest
@testable import ChewTheFat

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testFreshInstallStartsAtEULA() async throws {
        let env = try InMemoryEnvironment()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .eula)
    }

    func testEULAAcceptedButProfileEmptyAdvancesToProfileFRE() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: StubBootstrapper(isReady: false)
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .profileFRE)
    }

    func testProfileCompleteButNoGoalsAdvancesToGoalsFRE() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        if let p = try env.profile.current() {
            p.age = 35
            p.heightCm = 175
            p.sex = "male"
            try env.profile.save(p)
        }
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: StubBootstrapper(isReady: false)
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .goalsFRE)
    }

    func testFullyOnboardedButModelNotReadyShowsDownloading() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: StubBootstrapper(isReady: false)
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .downloadingAI)
    }

    func testFullyOnboardedAndModelReadySkipsToReady() async throws {
        let env = try InMemoryEnvironment()
        try env.completeOnboarding()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: NullModelBootstrapper()
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .ready)
    }

    func testProfileFRECompletionAdvancesToGoalsFRE() async throws {
        let env = try InMemoryEnvironment()
        try env.profile.acceptEULA()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: StubBootstrapper(isReady: false)
        )
        await coordinator.resolveInitialPhase()
        XCTAssertEqual(coordinator.phase, .profileFRE)

        coordinator.profileFREDidComplete()
        XCTAssertEqual(coordinator.phase, .goalsFRE)
    }

    func testGoalsFRECompletionJumpsToReadyIfModelOnDisk() async throws {
        let env = try InMemoryEnvironment()
        let coordinator = OnboardingCoordinator(
            profile: env.profile,
            goals: env.goals,
            bootstrapper: NullModelBootstrapper()
        )
        coordinator.goalsFREDidComplete()
        // The ready transition is dispatched through a Task; give it a tick.
        await Task.yield()
        await Task.yield()
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
