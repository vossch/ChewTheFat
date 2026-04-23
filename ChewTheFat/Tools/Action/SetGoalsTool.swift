import Foundation

@MainActor
struct SetGoalsTool: ToolProtocol {
    static let identifier: ToolIdentifier = .setGoals

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Save or update the user's nutrition goals (method, weekly weight change, calorie target, macros, ideal weight). Always pass all fields you want to set; omitted fields keep their current value.",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "method": .init(type: "string", description: "weightLoss | weightGain | maintenance"),
                    "weeklyChangeKg": .init(type: "number"),
                    "idealWeightKg": .init(type: "number"),
                    "calorieTarget": .init(type: "integer"),
                    "calorieIsManual": .init(type: "boolean"),
                    "proteinTargetG": .init(type: "number"),
                    "carbsTargetG": .init(type: "number"),
                    "fatTargetG": .init(type: "number"),
                    "macrosAreManual": .init(type: "boolean"),
                ],
                required: []
            )
        )
    }

    let goals: GoalRepository

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        let args = try arguments.decode(Args.self)
        let existing = try goals.current()
        let target = existing ?? UserGoals(
            method: args.method ?? "maintenance",
            weeklyChangeKg: args.weeklyChangeKg ?? 0,
            calorieTarget: args.calorieTarget ?? 2000,
            proteinTargetG: args.proteinTargetG ?? 100,
            carbsTargetG: args.carbsTargetG ?? 200,
            fatTargetG: args.fatTargetG ?? 70
        )
        if let v = args.method { target.method = v }
        if let v = args.weeklyChangeKg {
            let clamped = max(WeeklyChangeTarget.minKgPerWeek, min(WeeklyChangeTarget.maxKgPerWeek, v))
            target.weeklyChangeKg = clamped
        }
        if let v = args.idealWeightKg { target.idealWeightKg = v }
        if let v = args.calorieTarget { target.calorieTarget = v }
        if let v = args.calorieIsManual { target.calorieIsManual = v }
        if let v = args.proteinTargetG { target.proteinTargetG = v }
        if let v = args.carbsTargetG { target.carbsTargetG = v }
        if let v = args.fatTargetG { target.fatTargetG = v }
        if let v = args.macrosAreManual { target.macrosAreManual = v }

        try goals.save(target)

        struct Output: Encodable {
            let method: String
            let weeklyChangeKg: Double
            let calorieTarget: Int
            let proteinTargetG: Double
            let carbsTargetG: Double
            let fatTargetG: Double
            let idealWeightKg: Double?
        }
        return try .json(Output(
            method: target.method,
            weeklyChangeKg: target.weeklyChangeKg,
            calorieTarget: target.calorieTarget,
            proteinTargetG: target.proteinTargetG,
            carbsTargetG: target.carbsTargetG,
            fatTargetG: target.fatTargetG,
            idealWeightKg: target.idealWeightKg
        ))
    }

    private struct Args: Decodable {
        let method: String?
        let weeklyChangeKg: Double?
        let idealWeightKg: Double?
        let calorieTarget: Int?
        let calorieIsManual: Bool?
        let proteinTargetG: Double?
        let carbsTargetG: Double?
        let fatTargetG: Double?
        let macrosAreManual: Bool?
    }
}
