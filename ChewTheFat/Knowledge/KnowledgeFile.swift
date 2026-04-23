import Foundation

struct KnowledgeFile: Sendable, Hashable, Identifiable {
    let id: String
    let type: KnowledgeType
    let title: String
    let summary: String
    let tags: [String]
    let body: String
}
