import Foundation

struct FieldDescriptor: Hashable, Sendable, Codable {
    enum Group: String, Hashable, Sendable, Codable {
        case legal
        case profile
        case goals
        case composite
    }

    let key: String
    let label: String
    let group: Group
}

extension FieldDescriptor {
    static let eulaAccepted = FieldDescriptor(
        key: "userProfile.eulaAcceptedAt",
        label: "Terms of Service acceptance",
        group: .legal
    )
    static let preferredUnits = FieldDescriptor(
        key: "userProfile.preferredUnits",
        label: "Preferred units",
        group: .profile
    )
    static let birthYear = FieldDescriptor(
        key: "userProfile.birthYear",
        label: "Birth year",
        group: .profile
    )
    static let heightCm = FieldDescriptor(
        key: "userProfile.heightCm",
        label: "Height",
        group: .profile
    )
    static let biologicalSex = FieldDescriptor(
        key: "userProfile.sex",
        label: "Biological sex",
        group: .profile
    )
    static let activityLevel = FieldDescriptor(
        key: "userProfile.activityLevel",
        label: "Activity level",
        group: .profile
    )
    static let weeklyChangeKg = FieldDescriptor(
        key: "userGoals.weeklyChangeKg",
        label: "Weekly weight-change target",
        group: .goals
    )
    static let idealWeightKg = FieldDescriptor(
        key: "userGoals.idealWeightKg",
        label: "Ideal weight",
        group: .goals
    )
    static let calorieTarget = FieldDescriptor(
        key: "userGoals.calorieTarget",
        label: "Daily calorie target",
        group: .goals
    )
    static let onboardingComplete = FieldDescriptor(
        key: "session.onboardingComplete",
        label: "Complete onboarding",
        group: .composite
    )
}

struct SessionGoalContract: Hashable, Sendable {
    let goal: SessionGoal
    let requiredFields: [FieldDescriptor]
}

extension SessionGoalContract {
    static func contract(for goal: SessionGoal) -> SessionGoalContract {
        switch goal {
        case .onboarding:
            return SessionGoalContract(goal: goal, requiredFields: [
                .eulaAccepted,
                .preferredUnits,
                .birthYear,
                .heightCm,
                .biologicalSex,
                .activityLevel,
                .weeklyChangeKg,
                .idealWeightKg,
                .calorieTarget,
            ])
        case .logMeal, .logWeight, .userInsights, .general:
            return SessionGoalContract(goal: goal, requiredFields: [.onboardingComplete])
        }
    }
}

struct GoalProgress: Hashable, Sendable {
    let contract: SessionGoalContract
    let collected: [FieldDescriptor]
    let missing: [FieldDescriptor]

    var satisfied: Bool { missing.isEmpty }
}
