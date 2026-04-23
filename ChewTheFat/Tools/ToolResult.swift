import Foundation

struct ToolResult: Sendable {
    let payload: Data
    let widget: WidgetIntent?

    init(payload: Data, widget: WidgetIntent? = nil) {
        self.payload = payload
        self.widget = widget
    }

    static func empty(widget: WidgetIntent? = nil) -> ToolResult {
        ToolResult(payload: Data("{}".utf8), widget: widget)
    }

    static func json<Value: Encodable>(
        _ value: Value,
        widget: WidgetIntent? = nil,
        encoder: JSONEncoder = .init()
    ) throws -> ToolResult {
        ToolResult(payload: try encoder.encode(value), widget: widget)
    }

    var jsonString: String {
        String(data: payload, encoding: .utf8) ?? "{}"
    }
}
