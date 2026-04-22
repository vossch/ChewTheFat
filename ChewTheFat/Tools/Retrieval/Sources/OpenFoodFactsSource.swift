import Foundation

struct OpenFoodFactsSource: FoodReferenceSource {
    let db: OpenFoodFactsDB?
    var source: FoodSource { .openFoodFacts }

    func search(query: String, limit: Int) async throws -> [ReferenceFood] {
        guard let db else { return [] }
        return try await db.search(matching: query, limit: limit)
    }
}
