import Foundation

@MainActor
struct ProfileContextSource: ContextSourceProtocol {
    let profile: ProfileRepository

    nonisolated var name: String { "profile" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        guard let user = try? profile.current() else { return [] }
        var lines: [String] = []
        lines.append("- units: \(user.preferredUnits)")
        if user.age > 0 { lines.append("- age: \(user.age)") }
        if user.heightCm > 0 { lines.append("- height: \(user.heightCm) cm") }
        if !user.sex.isEmpty { lines.append("- sex: \(user.sex)") }
        if !user.activityLevel.isEmpty { lines.append("- activity: \(user.activityLevel)") }
        if user.eulaAcceptedAt == nil { lines.append("- terms: NOT YET ACCEPTED") }
        let body = "User profile:\n" + lines.joined(separator: "\n")
        return [ContextFragment(label: "Profile", body: body, priority: .critical)]
    }
}
