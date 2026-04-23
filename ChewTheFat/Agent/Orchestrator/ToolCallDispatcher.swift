import Foundation

/// Type-erased tool wrapper so the dispatcher can hold a heterogeneous
/// registry keyed by `ToolIdentifier`.
struct AnyTool: Sendable {
    let identifier: ToolIdentifier
    let schema: ToolSchema
    private let _invoke: @Sendable (ToolArguments) async throws -> ToolResult

    init<T: ToolProtocol>(_ tool: T) {
        self.identifier = T.identifier
        self.schema = T.schema
        self._invoke = { args in try await tool.invoke(args) }
    }

    func invoke(_ args: ToolArguments) async throws -> ToolResult {
        try await _invoke(args)
    }
}

@MainActor
final class ToolCallDispatcher {
    private var tools: [ToolIdentifier: AnyTool] = [:]

    func register(_ tool: AnyTool) {
        tools[tool.identifier] = tool
    }

    func register<T: ToolProtocol>(_ tool: T) {
        register(AnyTool(tool))
    }

    var schemas: [ToolSchema] {
        tools.values.map(\.schema).sorted { $0.identifier.rawValue < $1.identifier.rawValue }
    }

    func dispatch(_ call: ToolCallRequest) async -> ToolCallOutcome {
        guard let tool = tools[call.identifier] else {
            return .failure(call: call, error: .notFound(call.identifier.rawValue))
        }
        do {
            let result = try await tool.invoke(call.arguments)
            return .success(call: call, result: result)
        } catch let error as ToolError {
            return .failure(call: call, error: error)
        } catch {
            return .failure(call: call, error: .permanent(error.localizedDescription))
        }
    }
}

enum ToolCallOutcome: Sendable {
    case success(call: ToolCallRequest, result: ToolResult)
    case failure(call: ToolCallRequest, error: ToolError)

    var widget: WidgetIntent? {
        if case .success(_, let result) = self { return result.widget }
        return nil
    }

    var responseJSON: String {
        switch self {
        case .success(_, let result): return result.jsonString
        case .failure(_, let error):
            let payload = ["error": error.localizedDescription]
            let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    var call: ToolCallRequest {
        switch self {
        case .success(let call, _), .failure(let call, _): return call
        }
    }
}
