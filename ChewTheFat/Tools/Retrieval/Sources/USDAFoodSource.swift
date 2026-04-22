import Foundation

struct USDAFoodSource: FoodReferenceSource {
    let db: USDAFoodDB?
    var source: FoodSource { .usda }

    func search(query: String, limit: Int) async throws -> [ReferenceFood] {
        guard let db else { return [] }
        return try await db.search(matching: query, limit: limit)
    }
}
