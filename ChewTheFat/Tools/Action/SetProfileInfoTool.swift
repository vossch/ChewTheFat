import Foundation

@MainActor
struct SetProfileInfoTool: ToolProtocol {
    static let identifier: ToolIdentifier = .setProfileInfo

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Save or update profile fields gathered during onboarding (units, age, height, sex, activity level, EULA acceptance).",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "preferredUnits": .init(type: "string", description: "metric | imperial"),
                    "age": .init(type: "integer"),
                    "heightCm": .init(type: "number"),
                    "sex": .init(type: "string", description: "female | male | other"),
                    "activityLevel": .init(type: "string",
                                           enumValues: ActivityLevel.allCases.map(\.rawValue)),
                    "eulaAccepted": .init(type: "boolean"),
                ],
                required: []
            )
        )
    }

    let profile: ProfileRepository

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        let args = try arguments.decode(Args.self)
        let existing = try profile.current()
        let target = existing ?? UserProfile(
            age: args.age ?? 0,
            heightCm: args.heightCm ?? 0,
            sex: args.sex ?? "",
            preferredUnits: args.preferredUnits ?? "metric",
            activityLevel: args.activityLevel ?? ""
        )
        if let v = args.preferredUnits { target.preferredUnits = v }
        if let v = args.age { target.age = v }
        if let v = args.heightCm { target.heightCm = v }
        if let v = args.sex { target.sex = v }
        if let v = args.activityLevel { target.activityLevel = v }
        if args.eulaAccepted == true, target.eulaAcceptedAt == nil {
            target.eulaAcceptedAt = .now
        }
        try profile.save(target)

        struct Output: Encodable {
            let preferredUnits: String
            let age: Int
            let heightCm: Double
            let sex: String
            let activityLevel: String
            let eulaAccepted: Bool
        }
        return try .json(Output(
            preferredUnits: target.preferredUnits,
            age: target.age,
            heightCm: target.heightCm,
            sex: target.sex,
            activityLevel: target.activityLevel,
            eulaAccepted: target.eulaAcceptedAt != nil
        ))
    }

    private struct Args: Decodable {
        let preferredUnits: String?
        let age: Int?
        let heightCm: Double?
        let sex: String?
        let activityLevel: String?
        let eulaAccepted: Bool?
    }
}
