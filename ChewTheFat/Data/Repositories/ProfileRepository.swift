import Foundation
import SwiftData

@MainActor
struct ProfileRepository {
    let context: ModelContext

    func current() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try context.fetch(descriptor).first
    }

    func save(_ profile: UserProfile) throws {
        if profile.modelContext == nil {
            context.insert(profile)
        }
        try context.save()
    }

    func acceptEULA(on date: Date = .now) throws {
        guard let profile = try current() else { return }
        profile.eulaAcceptedAt = date
        try context.save()
    }
}
