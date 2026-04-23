import Foundation

protocol ToolProtocol: Sendable {
    static var identifier: ToolIdentifier { get }
    static var schema: ToolSchema { get }
    func invoke(_ arguments: ToolArguments) async throws -> ToolResult
}

extension ToolProtocol {
    var identifier: ToolIdentifier { Self.identifier }
    var schema: ToolSchema { Self.schema }
}
