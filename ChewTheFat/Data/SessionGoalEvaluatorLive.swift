import Foundation
import SwiftData

@MainActor
struct SessionGoalEvaluatorLive: SessionGoalEvaluator {
    let profile: ProfileRepository
    let goals: GoalRepository

    func evaluate(_ contract: SessionGoalContract) async -> GoalProgress {
        let userProfile = try? profile.current()
        let userGoals = try? goals.current()

        var collected: [FieldDescriptor] = []
        var missing: [FieldDescriptor] = []

        for field in contract.requiredFields {
            if isSatisfied(field, profile: userProfile, goals: userGoals) {
                collected.append(field)
            } else {
                missing.append(field)
            }
        }

        return GoalProgress(contract: contract, collected: collected, missing: missing)
    }

    private func isSatisfied(
        _ field: FieldDescriptor,
        profile: UserProfile?,
        goals: UserGoals?
    ) -> Bool {
        switch field.key {
        case FieldDescriptor.eulaAccepted.key:
            return profile?.eulaAcceptedAt != nil
        case FieldDescriptor.preferredUnits.key:
            return profile.map { !$0.preferredUnits.isEmpty } ?? false
        case FieldDescriptor.birthYear.key:
            return (profile?.age ?? 0) > 0
        case FieldDescriptor.heightCm.key:
            return (profile?.heightCm ?? 0) > 0
        case FieldDescriptor.biologicalSex.key:
            return profile.map { !$0.sex.isEmpty } ?? false
        case FieldDescriptor.activityLevel.key:
            return profile.map { !$0.activityLevel.isEmpty } ?? false
        case FieldDescriptor.weeklyChangeKg.key:
            return goals != nil
        case FieldDescriptor.idealWeightKg.key:
            return (goals?.idealWeightKg ?? 0) > 0
        case FieldDescriptor.calorieTarget.key:
            return (goals?.calorieTarget ?? 0) > 0
        case FieldDescriptor.onboardingComplete.key:
            return profile?.eulaAcceptedAt != nil
                && (profile?.age ?? 0) > 0
                && goals != nil
                && (goals?.calorieTarget ?? 0) > 0
        default:
            return false
        }
    }
}
