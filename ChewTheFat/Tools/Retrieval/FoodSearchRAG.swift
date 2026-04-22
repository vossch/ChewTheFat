import Foundation

struct FoodSearchRAG: Sendable {
    let history: FoodReferenceSource
    let usda: FoodReferenceSource
    let openFoodFacts: FoodReferenceSource
    let web: FoodReferenceSource
    let webFallbackEnabled: @Sendable () -> Bool

    func search(query: String, limit: Int = 20) async throws -> [ReferenceFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [ReferenceFood] = []
        var seen = Set<String>()

        for hit in try await history.search(query: trimmed, limit: limit) {
            if seen.insert(hit.id).inserted { results.append(hit) }
        }
        if results.count >= limit { return Array(results.prefix(limit)) }

        for hit in try await usda.search(query: trimmed, limit: limit) {
            if seen.insert(hit.id).inserted { results.append(hit) }
            if results.count >= limit { break }
        }
        if results.count >= limit { return Array(results.prefix(limit)) }

        for hit in try await openFoodFacts.search(query: trimmed, limit: limit) {
            if seen.insert(hit.id).inserted { results.append(hit) }
            if results.count >= limit { break }
        }

        if results.isEmpty && webFallbackEnabled() {
            for hit in try await web.search(query: trimmed, limit: limit) {
                if seen.insert(hit.id).inserted { results.append(hit) }
                if results.count >= limit { break }
            }
        }

        return Array(results.prefix(limit))
    }
}
