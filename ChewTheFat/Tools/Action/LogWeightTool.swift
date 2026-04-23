import Foundation

@MainActor
struct LogWeightTool: ToolProtocol {
    static let identifier: ToolIdentifier = .logWeight

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Record a weight entry for the user. Always store the value in kilograms.",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "weightKg": .init(type: "number", description: "Weight in kilograms."),
                    "date": .init(type: "string", description: "ISO 8601 date; defaults to today."),
                ],
                required: ["weightKg"]
            )
        )
    }

    let weightLog: WeightLogRepository

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        struct Args: Decodable { let weightKg: Double; let date: String? }
        let args = try arguments.decode(Args.self)
        let date = args.date.flatMap(ISO8601DateFormatter().date(from:)) ?? .now
        guard args.weightKg > 0, args.weightKg < 500 else {
            throw ToolError.invalidArguments("weightKg out of range")
        }
        let entry = try weightLog.log(weightKg: args.weightKg, date: date)
        struct Output: Encodable {
            let weightEntryId: String
            let weightKg: Double
            let date: String
        }
        let output = Output(
            weightEntryId: entry.id.uuidString,
            weightKg: entry.weightKg,
            date: ISO8601DateFormatter().string(from: entry.date)
        )
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: entry.date)
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let widget = WidgetIntent.weightGraph(
            WeightGraphPayload(dateRange: .init(start: start, end: end))
        )
        return try .json(output, widget: widget)
    }
}
