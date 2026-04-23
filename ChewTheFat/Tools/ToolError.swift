import Foundation

enum ToolError: Error, Sendable, Equatable {
    case invalidArguments(String)
    case notFound(String)
    case policyDenied(String)
    case transient(String)
    case permanent(String)
}

extension ToolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let detail): return "Invalid arguments: \(detail)"
        case .notFound(let detail): return "Not found: \(detail)"
        case .policyDenied(let detail): return "Policy denied: \(detail)"
        case .transient(let detail): return "Transient failure: \(detail)"
        case .permanent(let detail): return "Permanent failure: \(detail)"
        }
    }
}
