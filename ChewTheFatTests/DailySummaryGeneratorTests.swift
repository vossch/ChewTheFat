import XCTest
@testable import ChewTheFat

@MainActor
final class DailySummaryGeneratorTests: XCTestCase {
    func testComposeWithMealsAndWeight() throws {
        let env = try InMemoryEnvironment()
        let promoted = try env.foodCatalog.upsert(from: ReferenceFood(
            source: .usda,
            sourceRefId: "usda-summary-1",
            name: "Oatmeal",
            detail: nil,
            servings: [
                ReferenceServing(
                    measurementName: "cup",
                    calories: 150,
                    proteinG: 5,
                    carbsG: 27,
                    fatG: 3,
                    fiberG: 4
                )
            ]
        ))
        let serving = try XCTUnwrap(promoted.servings.first)
        let logged = try env.foodLog.log(
            foodEntry: promoted,
            serving: serving,
            quantity: 2,
            meal: .breakfast,
            date: .now
        )
        let weight = try env.weightLog.log(weightKg: 79.4, date: .now)

        let composed = DailySummaryGenerator.compose(
            for: .now,
            logs: [logged],
            weights: [weight]
        )
        XCTAssertTrue(composed.contains("300 kcal"))
        XCTAssertTrue(composed.contains("79.4 kg"))
        XCTAssertTrue(composed.contains("1 item"))
    }

    func testComposeWithEmptyDayDoesNotIncludeKcal() {
        let composed = DailySummaryGenerator.compose(
            for: .now,
            logs: [],
            weights: []
        )
        XCTAssertTrue(composed.contains("no meals logged"))
        XCTAssertFalse(composed.contains("kcal"))
    }

    func testRunIfNeededWritesAndStampsMarker() throws {
        let env = try InMemoryEnvironment()
        let preferences = AppPreferences(store: InMemoryPreferenceStore())
        XCTAssertNil(preferences.lastDailySummaryDay)

        let generator = DailySummaryGenerator(
            memory: env.memory,
            foodLog: env.foodLog,
            weightLog: env.weightLog,
            preferences: preferences
        )
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        _ = try env.weightLog.log(weightKg: 80, date: yesterday)

        generator.runIfNeeded()

        XCTAssertNotNil(preferences.lastDailySummaryDay)
        let entries = try env.memory.list(category: "dailySummary")
        XCTAssertEqual(entries.count, 1)
    }

    func testRunIfNeededIsIdempotent() throws {
        let env = try InMemoryEnvironment()
        let preferences = AppPreferences(store: InMemoryPreferenceStore())
        let generator = DailySummaryGenerator(
            memory: env.memory,
            foodLog: env.foodLog,
            weightLog: env.weightLog,
            preferences: preferences
        )
        generator.runIfNeeded()
        generator.runIfNeeded()
        let entries = try env.memory.list(category: "dailySummary")
        XCTAssertEqual(entries.count, 1, "second invocation must short-circuit on the marker")
    }
}
