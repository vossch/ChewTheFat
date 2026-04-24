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

    /// Records EULA acceptance, creating a placeholder profile if one doesn't
    /// yet exist. The profile's other fields are filled in during conversational
    /// onboarding via `SetProfileInfoTool`.
    func acceptEULA(on date: Date = .now) throws {
        if let profile = try current() {
            profile.eulaAcceptedAt = date
        } else {
            let profile = UserProfile(
                age: 0,
                heightCm: 0,
                sex: "",
                preferredUnits: "metric",
                activityLevel: "",
                eulaAcceptedAt: date
            )
            context.insert(profile)
        }
        try context.save()
    }
}
