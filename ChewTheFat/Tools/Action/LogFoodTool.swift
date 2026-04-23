import Foundation
import SwiftData

@MainActor
struct LogFoodTool: ToolProtocol {
    static let identifier: ToolIdentifier = .logFood

    static var schema: ToolSchema {
        ToolSchema(
            identifier: identifier,
            description: "Log one food item the user ate. Either reference an existing FoodEntry by `foodEntryId` and `servingId`, or pass `referenceFood` to promote a search hit into the SwiftData catalog before logging.",
            parameters: ToolSchema.ParameterSchema(
                properties: [
                    "foodEntryId": .init(type: "string", description: "Existing SwiftData FoodEntry UUID."),
                    "servingId": .init(type: "string", description: "Serving UUID belonging to the FoodEntry."),
                    "referenceFood": .init(type: "object", description: "Reference-DB hit to promote on first log."),
                    "referenceServingIndex": .init(type: "integer", description: "Index into referenceFood.servings."),
                    "quantity": .init(type: "number", description: "How many servings (e.g. 1.5)."),
                    "mealType": .init(type: "string", description: "breakfast | lunch | dinner | snack",
                                      enumValues: MealType.allCases.map(\.rawValue)),
                    "date": .init(type: "string", description: "ISO 8601 date; defaults to today."),
                ],
                required: ["quantity", "mealType"]
            )
        )
    }

    let foodLog: FoodLogRepository
    let foodCatalog: FoodCatalogRepository
    let context: ModelContext

    func invoke(_ arguments: ToolArguments) async throws -> ToolResult {
        let args = try arguments.decode(Args.self)
        guard let meal = MealType(rawValue: args.mealType) else {
            throw ToolError.invalidArguments("mealType")
        }
        let date = parseDate(args.date) ?? .now

        let entry: FoodEntry
        let serving: Serving
        if let foodEntryId = args.foodEntryId, let servingId = args.servingId,
           let entryUUID = UUID(uuidString: foodEntryId), let servingUUID = UUID(uuidString: servingId) {
            guard let resolvedEntry = try fetchEntry(id: entryUUID) else {
                throw ToolError.notFound("FoodEntry \(foodEntryId)")
            }
            guard let resolvedServing = resolvedEntry.servings.first(where: { $0.id == servingUUID }) else {
                throw ToolError.notFound("Serving \(servingId) on FoodEntry \(foodEntryId)")
            }
            entry = resolvedEntry
            serving = resolvedServing
        } else if let reference = args.referenceFood {
            let promoted = try foodCatalog.upsert(from: reference.toReferenceFood())
            let idx = max(0, min(args.referenceServingIndex ?? 0, promoted.servings.count - 1))
            guard !promoted.servings.isEmpty else {
                throw ToolError.invalidArguments("referenceFood has no servings")
            }
            entry = promoted
            serving = promoted.servings[idx]
        } else {
            throw ToolError.invalidArguments("must provide foodEntryId+servingId or referenceFood")
        }

        let logged = try foodLog.log(
            foodEntry: entry,
            serving: serving,
            quantity: args.quantity,
            meal: meal,
            date: date
        )

        struct Output: Encodable {
            let loggedFoodId: String
            let foodEntryId: String
            let mealType: String
            let date: String
        }
        let output = Output(
            loggedFoodId: logged.id.uuidString,
            foodEntryId: entry.id.uuidString,
            mealType: meal.rawValue,
            date: ISO8601DateFormatter().string(from: logged.date)
        )
        let widget = WidgetIntent.mealCard(
            MealCardPayload(loggedFoodIds: [logged.id], mealType: meal, date: logged.date)
        )
        return try .json(output, widget: widget)
    }

    private func fetchEntry(id: UUID) throws -> FoodEntry? {
        let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private struct Args: Decodable {
        let foodEntryId: String?
        let servingId: String?
        let referenceFood: ReferenceFoodDTO?
        let referenceServingIndex: Int?
        let quantity: Double
        let mealType: String
        let date: String?
    }

    private struct ReferenceFoodDTO: Decodable {
        let source: String
        let sourceRefId: String
        let name: String
        let detail: String?
        let servings: [ServingDTO]

        struct ServingDTO: Decodable {
            let measurementName: String
            let calories: Double
            let proteinG: Double
            let carbsG: Double
            let fatG: Double
            let fiberG: Double
        }

        func toReferenceFood() -> ReferenceFood {
            ReferenceFood(
                source: FoodSource(rawValue: source) ?? .manual,
                sourceRefId: sourceRefId,
                name: name,
                detail: detail,
                servings: servings.map {
                    ReferenceServing(
                        measurementName: $0.measurementName,
                        calories: $0.calories,
                        proteinG: $0.proteinG,
                        carbsG: $0.carbsG,
                        fatG: $0.fatG,
                        fiberG: $0.fiberG
                    )
                }
            )
        }
    }
}
