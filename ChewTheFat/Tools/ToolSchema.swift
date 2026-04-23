import Foundation

struct ToolSchema: Sendable, Codable {
    let identifier: ToolIdentifier
    let description: String
    let parameters: ParameterSchema

    struct ParameterSchema: Sendable, Codable {
        let type: String
        let properties: [String: PropertySchema]
        let required: [String]

        init(properties: [String: PropertySchema], required: [String]) {
            self.type = "object"
            self.properties = properties
            self.required = required
        }
    }

    struct PropertySchema: Sendable, Codable {
        let type: String
        let description: String?
        let enumValues: [String]?
        let items: ItemSchema?

        init(
            type: String,
            description: String? = nil,
            enumValues: [String]? = nil,
            items: ItemSchema? = nil
        ) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
        }

        enum CodingKeys: String, CodingKey {
            case type
            case description
            case enumValues = "enum"
            case items
        }
    }

    struct ItemSchema: Sendable, Codable {
        let type: String
    }
}
