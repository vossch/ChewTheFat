import Foundation

/// Classifies a newly-logged weight against recent history + goal cadence.
/// Emitted by GoalRepository and surfaced in LogWeightTool's JSON so the
/// model can phrase acknowledgement tone (per US3 Scenario 3). The app
/// never generates coaching prose itself.
nonisolated enum CoachingFlag: String, Codable, Sendable, Hashable {
    case normal
    case rapidLoss
    case rapidGain
    case plateau
}
