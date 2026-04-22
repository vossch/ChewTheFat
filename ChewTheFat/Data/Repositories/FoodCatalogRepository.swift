import Foundation
import SwiftData

@MainActor
struct FoodCatalogRepository {
    let context: ModelContext

    @discardableResult
    func upsert(from reference: ReferenceFood) throws -> FoodEntry {
        let sourceRaw = reference.source.rawValue
        let refId = reference.sourceRefId

        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.source == sourceRaw && $0.sourceRefId == refId }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.lastLoggedAt = .now
            existing.logCount += 1
            try context.save()
            return existing
        }

        let tokens = Self.searchTokens(name: reference.name, detail: reference.detail)
        let entry = FoodEntry(
            name: reference.name,
            detail: reference.detail,
            source: sourceRaw,
            sourceRefId: refId,
            lastLoggedAt: .now,
            logCount: 1,
            searchTokens: tokens
        )
        context.insert(entry)

        for refServing in reference.servings {
            let serving = Serving(
                measurementName: refServing.measurementName,
                calories: refServing.calories,
                proteinG: refServing.proteinG,
                carbsG: refServing.carbsG,
                fatG: refServing.fatG,
                fiberG: refServing.fiberG,
                foodEntry: entry
            )
            context.insert(serving)
        }

        try context.save()
        return entry
    }

    func find(source: FoodSource, sourceRefId: String) throws -> FoodEntry? {
        let sourceRaw = source.rawValue
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.source == sourceRaw && $0.sourceRefId == sourceRefId }
        )
        return try context.fetch(descriptor).first
    }

    func createManual(
        name: String,
        detail: String? = nil,
        servings: [ReferenceServing]
    ) throws -> FoodEntry {
        precondition(!servings.isEmpty, "Manual FoodEntry requires at least one Serving")
        let entry = FoodEntry(
            name: name,
            detail: detail,
            source: FoodSource.manual.rawValue,
            sourceRefId: nil,
            lastLoggedAt: .now,
            logCount: 0,
            searchTokens: Self.searchTokens(name: name, detail: detail)
        )
        context.insert(entry)
        for refServing in servings {
            let serving = Serving(
                measurementName: refServing.measurementName,
                calories: refServing.calories,
                proteinG: refServing.proteinG,
                carbsG: refServing.carbsG,
                fatG: refServing.fatG,
                fiberG: refServing.fiberG,
                foodEntry: entry
            )
            context.insert(serving)
        }
        try context.save()
        return entry
    }

    static func searchTokens(name: String, detail: String?) -> String {
        let combined = [name, detail ?? ""]
            .joined(separator: " ")
            .lowercased()
        let parts = combined
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }
}
