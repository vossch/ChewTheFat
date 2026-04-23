import Foundation

enum ModelStreamEvent: Sendable, Hashable {
    case text(String)
    case toolCall(ToolCallRequest)
    case widget(WidgetIntent)
    case finished(FinishReason)
}

enum FinishReason: String, Sendable, Hashable, Codable {
    case stop
    case maxTokens
    case toolCall
    case error
}

nonisolated struct ToolCallRequest: Sendable, Hashable, Codable {
    let id: String
    let identifier: ToolIdentifier
    let argumentsJSON: String

    init(id: String = UUID().uuidString, identifier: ToolIdentifier, argumentsJSON: String) {
        self.id = id
        self.identifier = identifier
        self.argumentsJSON = argumentsJSON
    }

    var arguments: ToolArguments {
        ToolArguments(json: argumentsJSON)
    }
}

struct ModelResponse: Sendable {
    let text: String
    let toolCalls: [ToolCallRequest]
    let widgets: [WidgetIntent]
    let finishReason: FinishReason
}
