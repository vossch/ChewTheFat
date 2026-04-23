import Foundation

struct LookupKnowledgeTool: ToolProtocol {
    static let identifier: ToolIdentifier = .lookupKnowledge

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Fetch a knowledge file by id from the bundled markdown library. Use this when you need a goal/skill/reference body that wasn't already in context.",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "id": .init(
                        type: "string",
                        description: "Knowledge file id, e.g. \"skill-onboarding\" or \"reference-macronutrients\"."
                    ),
                ],
                required: ["id"]
            )
        )
    }

    let graph: KnowledgeGraph

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        struct Args: Decodable { let id: String }
        let args = try arguments.decode(Args.self)
        guard let file = await graph.file(id: args.id) else {
            throw ToolError.notFound("knowledge id \(args.id)")
        }
        struct Output: Encodable {
            let id: String
            let title: String
            let summary: String
            let body: String
        }
        return try .json(Output(id: file.id, title: file.title, summary: file.summary, body: file.body))
    }
}
