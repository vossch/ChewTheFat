import Foundation

struct WebSearchFallback: FoodReferenceSource {
    var source: FoodSource { .web }

    func search(query: String, limit: Int) async throws -> [ReferenceFood] {
        []
    }
}
