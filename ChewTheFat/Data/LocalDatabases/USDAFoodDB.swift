import Foundation

#if canImport(GRDB)
import GRDB

struct USDAFoodDB: Sendable {
    let pool: DatabasePool

    init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReferenceDatabaseError.fileMissing(url)
        }
        var config = Configuration()
        config.readonly = true
        self.pool = try DatabasePool(path: url.path, configuration: config)
    }

    func search(matching query: String, limit: Int) async throws -> [ReferenceFood] {
        let ftsQuery = ReferenceFoodQuery.ftsQuery(from: query)
        guard !ftsQuery.isEmpty else { return [] }
        return try await pool.read { db in
            try ReferenceFoodQuery.fetchAll(
                db: db,
                ftsQuery: ftsQuery,
                limit: limit,
                source: .usda
            )
        }
    }
}
#else
struct USDAFoodDB: Sendable {
    init(url: URL) throws {
        throw ReferenceDatabaseError.grdbUnavailable
    }

    func search(matching query: String, limit: Int) async throws -> [ReferenceFood] {
        []
    }
}
#endif
