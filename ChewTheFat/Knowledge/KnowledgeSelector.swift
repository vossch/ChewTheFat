import Foundation

struct KnowledgeSelection: Sendable {
    let files: [KnowledgeFile]
}

struct KnowledgeSelector: Sendable {
    func selectFor(goal: SessionGoal, in graph: KnowledgeIndex) -> KnowledgeSelection {
        let preferredIds: [String]
        switch goal {
        case .onboarding:
            preferredIds = ["skill-onboarding", "reference-macronutrients"]
        case .logMeal:
            preferredIds = ["skill-meal-logging", "reference-macronutrients"]
        case .logWeight:
            preferredIds = ["skill-weight-tracking"]
        case .userInsights:
            preferredIds = ["reference-macronutrients"]
        case .general:
            preferredIds = ["index"]
        }
        let selected = preferredIds.compactMap { graph.file(id: $0) }
        return KnowledgeSelection(files: selected)
    }
}
