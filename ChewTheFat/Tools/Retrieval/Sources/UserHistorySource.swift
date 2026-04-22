import Foundation
import SwiftData

@MainActor
struct UserHistorySource: FoodReferenceSource {
    let context: ModelContext
    var source: FoodSource { .manual }

    func search(query: String, limit: Int) async throws -> [ReferenceFood] {
        let tokens = Self.tokenize(query)
        guard !tokens.isEmpty else { return [] }

        let descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [
                SortDescriptor(\.logCount, order: .reverse),
                SortDescriptor(\.lastLoggedAt, order: .reverse),
            ]
        )
        let entries = try context.fetch(descriptor)

        let now = Date()
        let scored: [(FoodEntry, Double)] = entries.compactMap { entry in
            let matches = Self.matchCount(haystack: entry.searchTokens, needles: tokens)
            guard matches > 0 else { return nil }
            let recency = Self.recencyScore(from: entry.lastLoggedAt, now: now)
            let score = Double(matches) * (1.0 + log(Double(entry.logCount + 1))) * recency
            return (entry, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { entry, score in
                ReferenceFood(
                    source: foodSource(for: entry.source),
                    sourceRefId: entry.sourceRefId ?? entry.id.uuidString,
                    name: entry.name,
                    detail: entry.detail,
                    servings: entry.servings.map { serving in
                        ReferenceServing(
                            measurementName: serving.measurementName,
                            calories: serving.calories,
                            proteinG: serving.proteinG,
                            carbsG: serving.carbsG,
                            fatG: serving.fatG,
                            fiberG: serving.fiberG
                        )
                    },
                    score: score
                )
            }
    }

    static func tokenize(_ raw: String) -> [String] {
        raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func matchCount(haystack: String, needles: [String]) -> Int {
        let haystackTokens = Set(haystack.components(separatedBy: .whitespaces))
        var matches = 0
        for needle in needles {
            if haystackTokens.contains(where: { $0.hasPrefix(needle) }) {
                matches += 1
            }
        }
        return matches
    }

    static func recencyScore(from date: Date, now: Date) -> Double {
        let days = max(0, now.timeIntervalSince(date) / 86_400)
        return 1.0 / (1.0 + days / 30.0)
    }

    private func foodSource(for raw: String) -> FoodSource {
        FoodSource(rawValue: raw) ?? .manual
    }
}
