import Foundation
import SwiftData

@MainActor
struct GoalRepository {
    let context: ModelContext

    func current() throws -> UserGoals? {
        let descriptor = FetchDescriptor<UserGoals>()
        return try context.fetch(descriptor).first
    }

    func save(_ goals: UserGoals) throws {
        if goals.modelContext == nil {
            context.insert(goals)
        }
        goals.updatedAt = .now
        try context.save()
    }
}
