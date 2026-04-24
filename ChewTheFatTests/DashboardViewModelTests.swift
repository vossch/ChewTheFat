import XCTest
@testable import ChewTheFat

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testEmptyStateWhenNoHistory() throws {
        let env = try InMemoryEnvironment()
        let vm = DashboardViewModel(sessions: env.sessions, weightLog: env.weightLog)

        vm.reload()

        XCTAssertFalse(vm.hasAnyWeightHistory)
        XCTAssertTrue(vm.showsTrajectoryEmptyState)
        XCTAssertFalse(vm.showsChatHistory) // no non-onboarding sessions
        XCTAssertNil(vm.latestWeightKg)
    }

    func testPopulatedStateHidesEmptyStates() throws {
        let env = try InMemoryEnvironment()
        _ = try env.weightLog.log(weightKg: 80, date: .now)
        _ = try env.sessions.create(goal: .general)

        let vm = DashboardViewModel(sessions: env.sessions, weightLog: env.weightLog)
        vm.reload()

        XCTAssertTrue(vm.hasAnyWeightHistory)
        XCTAssertFalse(vm.showsTrajectoryEmptyState)
        XCTAssertTrue(vm.showsChatHistory)
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.latestWeightKg, 80)
    }

    func testOnboardingSessionsAreFilteredFromChatHistory() throws {
        let env = try InMemoryEnvironment()
        _ = try env.sessions.create(goal: .onboarding)

        let vm = DashboardViewModel(sessions: env.sessions, weightLog: env.weightLog)
        vm.reload()

        XCTAssertFalse(vm.showsChatHistory)
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    func testTrajectoryRangeSpansWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = DashboardViewModel(
            sessions: DashboardStubs.sessions,
            weightLog: DashboardStubs.weightLog,
            today: now,
            trajectoryWindowDays: 30
        )

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: vm.trajectoryRange.lowerBound,
            to: vm.trajectoryRange.upperBound
        ).day
        XCTAssertEqual(days, 30)
    }
}

@MainActor
private enum DashboardStubs {
    static let env = try! InMemoryEnvironment()
    static var sessions: SessionRepository { env.sessions }
    static var weightLog: WeightLogRepository { env.weightLog }
}
