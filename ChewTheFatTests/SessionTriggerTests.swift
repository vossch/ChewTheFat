import XCTest
@testable import ChewTheFat

@MainActor
final class SessionTriggerTests: XCTestCase {
    private func date(hour: Int, minute: Int = 0, day: Int = 25) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    func testWeighInWinsBeforeBreakfastSlotWhenNoWeightToday() {
        let now = date(hour: 8)
        let trigger = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: nil,
            loggedMealsToday: [],
            recentMealSummaries: { _ in [] }
        ))
        XCTAssertEqual(trigger.recommendedGoal, .logWeight)
        XCTAssertTrue(trigger.shouldAutoStart)
        XCTAssertTrue(trigger.slotId.hasPrefix("weighIn-"))
    }

    func testBreakfastSlotFiresAfterWeightAlreadyLoggedToday() {
        let now = date(hour: 9)
        let trigger = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: now,
            loggedMealsToday: [],
            recentMealSummaries: { _ in ["eggs and toast"] }
        ))
        XCTAssertEqual(trigger.recommendedGoal, .logMeal)
        XCTAssertEqual(trigger.mealType, .breakfast)
        XCTAssertEqual(trigger.suggestions, ["eggs and toast"])
        XCTAssertTrue(trigger.slotId.hasPrefix("breakfast-"))
    }

    func testLunchSlotFires() {
        let now = date(hour: 13)
        let trigger = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: now,
            loggedMealsToday: [.breakfast],
            recentMealSummaries: { _ in [] }
        ))
        XCTAssertEqual(trigger.recommendedGoal, .logMeal)
        XCTAssertEqual(trigger.mealType, .lunch)
    }

    func testDinnerSuppressedWhenAlreadyLogged() {
        let now = date(hour: 19)
        let trigger = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: now,
            loggedMealsToday: [.dinner],
            recentMealSummaries: { _ in [] }
        ))
        XCTAssertEqual(trigger.recommendedGoal, .general)
        XCTAssertFalse(trigger.shouldAutoStart)
    }

    func testOutOfWindowReturnsGeneral() {
        let now = date(hour: 23)
        let trigger = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: now,
            lastWeightLogDate: nil,
            loggedMealsToday: [],
            recentMealSummaries: { _ in [] }
        ))
        XCTAssertEqual(trigger.recommendedGoal, .general)
    }

    func testSlotIdIsStableWithinSameDay() {
        let morning = date(hour: 8)
        let later = date(hour: 10, minute: 30)
        let a = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: morning,
            lastWeightLogDate: nil,
            loggedMealsToday: [],
            recentMealSummaries: { _ in [] }
        ))
        let b = SessionTrigger.evaluate(SessionTrigger.Inputs(
            now: later,
            lastWeightLogDate: nil,
            loggedMealsToday: [],
            recentMealSummaries: { _ in [] }
        ))
        XCTAssertEqual(a.slotId, b.slotId)
    }
}
