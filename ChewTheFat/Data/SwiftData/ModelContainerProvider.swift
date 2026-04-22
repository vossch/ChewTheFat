import Foundation
import SwiftData

enum ModelContainerProvider {
    static func live() throws -> ModelContainer {
        let config = ModelConfiguration(schema: ChewTheFatSchema.current)
        return try ModelContainer(
            for: ChewTheFatSchema.current,
            migrationPlan: ChewTheFatMigrationPlan.self,
            configurations: config
        )
    }

    static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: ChewTheFatSchema.current,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: ChewTheFatSchema.current,
            migrationPlan: ChewTheFatMigrationPlan.self,
            configurations: config
        )
    }
}
