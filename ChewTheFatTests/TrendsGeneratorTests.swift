import XCTest
@testable import ChewTheFat

@MainActor
final class TrendsGeneratorTests: XCTestCase {
    private func date(daysAgo: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    func testWeightAverageOver7DayWindow() {
        let now = Date()
        let entries: [WeightEntry] = [
            WeightEntry(date: date(daysAgo: 0, from: now), weightKg: 80),
            WeightEntry(date: date(daysAgo: 3, from: now), weightKg: 81),
            WeightEntry(date: date(daysAgo: 6, from: now), weightKg: 82),
        ]
        let summary = TrendsGenerator.summarize(weights: entries)
        XCTAssertEqual(summary?.averageKg ?? 0, 81, accuracy: 0.01)
        XCTAssertEqual(summary?.entries, 3)
    }

    func testEmptyWeightWindowReturnsNil() {
        XCTAssertNil(TrendsGenerator.summarize(weights: []))
    }

    func testMacroAverageDividesByWindow() throws {
        let env = try InMemoryEnvironment()
        let promoted = try env.foodCatalog.upsert(from: ReferenceFood(
            source: .usda,
            sourceRefId: "usda-trends-1",
            name: "Egg",
            detail: nil,
            servings: [
                ReferenceServing(
                    measurementName: "egg",
                    calories: 70,
                    proteinG: 6,
                    carbsG: 0.4,
                    fatG: 5,
                    fiberG: 0
                )
            ]
        ))
        let serving = try XCTUnwrap(promoted.servings.first)
        let logged: [LoggedFood] = try (0..<3).map { offset in
            try env.foodLog.log(
                foodEntry: promoted,
                serving: serving,
                quantity: 2,
                meal: .breakfast,
                date: Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
            )
        }
        let macros = TrendsGenerator.summarize(loggedFoods: logged, windowDays: 7)
        // 3 days × 2 eggs × 70 kcal = 420 kcal total ÷ 7 days = 60 avg
        XCTAssertEqual(macros.averageCalories, 60, accuracy: 0.5)
        XCTAssertEqual(macros.daysCovered, 3)
    }

    func testMarkStaleAndRecomputeFlow() throws {
        let env = try InMemoryEnvironment()
        let trends = TrendsRepository(context: env.context)

        let foodLog = FoodLogRepository(context: env.context, onChange: { try? trends.markStale() })
        let weightLog = WeightLogRepository(context: env.context, onChange: { try? trends.markStale() })

        _ = try weightLog.log(weightKg: 80, date: .now)
        XCTAssertTrue(try trends.current().isStale)

        let generator = TrendsGenerator(trends: trends, weightLog: weightLog, foodLog: foodLog)
        try generator.recomputeIfStale()
        XCTAssertFalse(try trends.current().isStale)

        let weightSummary = try trends.decodedWeight()
        XCTAssertEqual(weightSummary?.entries, 1)
        XCTAssertEqual(weightSummary?.averageKg ?? 0, 80, accuracy: 0.01)
    }
}
