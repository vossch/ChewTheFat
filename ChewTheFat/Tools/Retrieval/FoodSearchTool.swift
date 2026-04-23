import Foundation

struct FoodSearchTool: ToolProtocol {
    static let identifier: ToolIdentifier = .foodSearch

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Search the local food databases (USDA + Open Food Facts) and the user's own history. Returns up to `limit` candidate foods with their nutrition.",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "query": .init(type: "string", description: "Plain-English food name, e.g. \"oatmeal\"."),
                    "limit": .init(type: "integer", description: "Max results, default 5."),
                ],
                required: ["query"]
            )
        )
    }

    let rag: FoodSearchRAG

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        struct Args: Decodable { let query: String; let limit: Int? }
        let args = try arguments.decode(Args.self)
        let limit = max(1, min(args.limit ?? 5, 20))
        let results = try await rag.search(query: args.query, limit: limit)
        struct Output: Encodable { let results: [ResultDTO] }
        struct ResultDTO: Encodable {
            let id: String
            let source: String
            let sourceRefId: String
            let name: String
            let detail: String?
            let servings: [ServingDTO]
        }
        struct ServingDTO: Encodable {
            let measurementName: String
            let calories: Double
            let proteinG: Double
            let carbsG: Double
            let fatG: Double
            let fiberG: Double
        }
        let dto = Output(results: results.map {
            ResultDTO(
                id: $0.id,
                source: $0.source.rawValue,
                sourceRefId: $0.sourceRefId,
                name: $0.name,
                detail: $0.detail,
                servings: $0.servings.map {
                    ServingDTO(
                        measurementName: $0.measurementName,
                        calories: $0.calories,
                        proteinG: $0.proteinG,
                        carbsG: $0.carbsG,
                        fatG: $0.fatG,
                        fiberG: $0.fiberG
                    )
                }
            )
        })
        return try .json(dto)
    }
}
