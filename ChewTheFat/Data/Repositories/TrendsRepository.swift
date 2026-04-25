import Foundation
import SwiftData

/// Wraps the singleton `Trends` row. The model is created lazily on first
/// access and stays around for the life of the container — there is at most
/// one `Trends` per device. Other repositories call `markStale()` when their
/// writes invalidate the cached aggregates; `TrendsGenerator` flips it back
/// to fresh on the next foreground tick.
@MainActor
struct TrendsRepository {
    let context: ModelContext

    func current() throws -> Trends {
        let descriptor = FetchDescriptor<Trends>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let row = Trends()
        context.insert(row)
        try context.save()
        return row
    }

    func markStale() throws {
        let row = try current()
        guard !row.isStale else { return }
        row.isStale = true
        try context.save()
    }

    func writeWeight(
        payload: TrendsWeightSummary,
        rangeStart: Date?,
        rangeEnd: Date?
    ) throws {
        let row = try current()
        row.weightTrendPayload = try JSONEncoder().encode(payload)
        row.weightRangeStart = rangeStart
        row.weightRangeEnd = rangeEnd
        row.updatedAt = .now
        try context.save()
    }

    func writeMacros(
        payload: TrendsMacroSummary,
        rangeStart: Date?,
        rangeEnd: Date?
    ) throws {
        let row = try current()
        row.macroTrendPayload = try JSONEncoder().encode(payload)
        row.macroRangeStart = rangeStart
        row.macroRangeEnd = rangeEnd
        row.updatedAt = .now
        try context.save()
    }

    func clearStale() throws {
        let row = try current()
        guard row.isStale else { return }
        row.isStale = false
        try context.save()
    }

    func decodedWeight() throws -> TrendsWeightSummary? {
        let row = try current()
        guard let data = row.weightTrendPayload else { return nil }
        return try? JSONDecoder().decode(TrendsWeightSummary.self, from: data)
    }

    func decodedMacros() throws -> TrendsMacroSummary? {
        let row = try current()
        guard let data = row.macroTrendPayload else { return nil }
        return try? JSONDecoder().decode(TrendsMacroSummary.self, from: data)
    }
}

struct TrendsWeightSummary: Codable, Hashable, Sendable {
    let averageKg: Double
    let entries: Int
    let firstDate: Date?
    let lastDate: Date?
}

struct TrendsMacroSummary: Codable, Hashable, Sendable {
    let averageCalories: Double
    let averageProteinG: Double
    let averageCarbsG: Double
    let averageFatG: Double
    let daysCovered: Int
}
