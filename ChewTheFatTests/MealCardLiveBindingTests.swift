import XCTest
@testable import ChewTheFat

/// M3 "Done when" #3: editing an underlying `LoggedFood` in the store must
/// re-render any widget that references it. This validates the dataflow
/// invariant that widget payloads carry references, not snapshots — the
/// view-model resolves ids against the repository at every reload.
@MainActor
final class MealCardLiveBindingTests: XCTestCase {
    func testEditingLoggedFoodQuantity_reflectsInSnapshotViewModelOnReload() throws {
        let env = try InMemoryEnvironment()

        // Seed a FoodEntry + Serving via the promotion path.
        let promoted = try env.foodCatalog.upsert(from: ReferenceFood(
            source: .usda,
            sourceRefId: "usda-test-1",
            name: "Egg, whole",
            detail: "large",
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

        // Log the initial quantity.
        let logged = try env.foodLog.log(
            foodEntry: promoted,
            serving: serving,
            quantity: 1,
            meal: .breakfast,
            date: Date()
        )

        let vm = MealCardViewModel(
            mode: .snapshot(ids: [logged.id]),
            foodLog: env.foodLog,
            dateContext: logged.date
        )
        vm.reload()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(Int(vm.totals.calories.rounded()), 70)

        // Edit the underlying LoggedFood.
        logged.quantity = 3
        try env.context.save()

        vm.reload()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(Int(vm.totals.calories.rounded()), 210, "widget must reflect new quantity")
    }

    func testLiveMode_reactsToNewLogsForSameMealDate() throws {
        let env = try InMemoryEnvironment()

        let promoted = try env.foodCatalog.upsert(from: ReferenceFood(
            source: .usda,
            sourceRefId: "usda-test-live",
            name: "Toast",
            detail: nil,
            servings: [
                ReferenceServing(
                    measurementName: "slice",
                    calories: 80,
                    proteinG: 3,
                    carbsG: 15,
                    fatG: 1,
                    fiberG: 1
                )
            ]
        ))
        let serving = try XCTUnwrap(promoted.servings.first)
        let day = Date()

        let vm = MealCardViewModel(
            mode: .live(meal: .breakfast, date: day),
            foodLog: env.foodLog,
            dateContext: day
        )
        vm.reload()
        XCTAssertEqual(vm.items.count, 0)

        _ = try env.foodLog.log(
            foodEntry: promoted,
            serving: serving,
            quantity: 2,
            meal: .breakfast,
            date: day
        )

        vm.reload()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(Int(vm.totals.calories.rounded()), 160)
    }
}
