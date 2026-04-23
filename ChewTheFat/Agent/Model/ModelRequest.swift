import Foundation

struct ModelRequest: Sendable {
    let systemPrompt: String
    let messages: [ChatMessage]
    let tools: [ToolSchema]
    let widgetSchemas: [WidgetSchema]
    let parameters: GenerationParameters

    init(
        systemPrompt: String,
        messages: [ChatMessage],
        tools: [ToolSchema] = [],
        widgetSchemas: [WidgetSchema] = [],
        parameters: GenerationParameters = .init()
    ) {
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.tools = tools
        self.widgetSchemas = widgetSchemas
        self.parameters = parameters
    }
}

struct ChatMessage: Sendable, Hashable, Codable {
    enum Role: String, Sendable, Hashable, Codable {
        case system
        case user
        case assistant
        case tool
    }

    let role: Role
    let content: String
    let toolCallId: String?

    init(role: Role, content: String, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
    }
}

struct WidgetSchema: Sendable, Codable {
    let type: String
    let description: String
    let payloadSchema: ToolSchema.ParameterSchema
}

struct GenerationParameters: Sendable {
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    var stopSequences: [String]

    init(
        maxTokens: Int = 1024,
        temperature: Double = 0.4,
        topP: Double = 0.9,
        stopSequences: [String] = []
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
    }
}
