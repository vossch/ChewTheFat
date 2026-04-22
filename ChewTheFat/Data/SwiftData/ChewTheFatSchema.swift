import Foundation
import SwiftData

enum ChewTheFatSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            UserGoals.self,
            Session.self,
            Message.self,
            MessageWidget.self,
            FoodEntry.self,
            Serving.self,
            LoggedFood.self,
            WeightEntry.self,
            DailySummary.self,
            Memory.self,
            Trends.self,
        ]
    }
}

enum ChewTheFatMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ChewTheFatSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum ChewTheFatSchema {
    static let current = Schema(versionedSchema: ChewTheFatSchemaV1.self)
}
