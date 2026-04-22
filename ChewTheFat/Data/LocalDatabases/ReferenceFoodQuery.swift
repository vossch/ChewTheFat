import Foundation

#if canImport(GRDB)
import GRDB

enum ReferenceFoodQuery {
    static func ftsQuery(from raw: String) -> String {
        let tokens = raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "" }
        return tokens.map { "\($0)*" }.joined(separator: " ")
    }

    static func fetchAll(
        db: Database,
        ftsQuery: String,
        limit: Int,
        source: FoodSource
    ) throws -> [ReferenceFood] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT
                fe.id AS id,
                fe.name AS name,
                fe.description AS description,
                s.measurement_name AS measurement_name,
                s.calories AS calories,
                s.protein_g AS protein_g,
                s.carbs_g AS carbs_g,
                s.fat_g AS fat_g,
                s.fiber_g AS fiber_g,
                bm25(food_fts) AS rank
            FROM food_fts
            JOIN food_entry fe ON food_fts.rowid = fe.rowid
            JOIN serving s ON s.food_entry_id = fe.id
            WHERE food_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """,
            arguments: [ftsQuery, limit * 5]
        )

        var byId: [String: (ReferenceFood, Double)] = [:]
        var ordering: [String] = []
        for row in rows {
            let id: String = row["id"]
            let name: String = row["name"]
            let description: String? = row["description"]
            let measurement: String = row["measurement_name"]
            let calories: Double = row["calories"]
            let protein: Double = row["protein_g"]
            let carbs: Double = row["carbs_g"]
            let fat: Double = row["fat_g"]
            let fiber: Double = row["fiber_g"]
            let rank: Double = row["rank"] ?? 0
            let serving = ReferenceServing(
                measurementName: measurement,
                calories: calories,
                proteinG: protein,
                carbsG: carbs,
                fatG: fat,
                fiberG: fiber
            )
            if var entry = byId[id] {
                entry.0 = ReferenceFood(
                    source: entry.0.source,
                    sourceRefId: entry.0.sourceRefId,
                    name: entry.0.name,
                    detail: entry.0.detail,
                    servings: entry.0.servings + [serving],
                    score: entry.1
                )
                byId[id] = entry
            } else {
                ordering.append(id)
                let entry = ReferenceFood(
                    source: source,
                    sourceRefId: id,
                    name: name,
                    detail: description,
                    servings: [serving],
                    score: -rank
                )
                byId[id] = (entry, -rank)
            }
            if ordering.count >= limit && byId[id] != nil {
                // keep filling servings for ids we've already accepted
            }
        }
        return ordering.prefix(limit).compactMap { byId[$0]?.0 }
    }
}
#endif
