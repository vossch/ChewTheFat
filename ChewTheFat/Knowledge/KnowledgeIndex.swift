import Foundation

nonisolated struct KnowledgeIndex: Sendable {
    let entries: [KnowledgeFile]

    func file(id: String) -> KnowledgeFile? {
        entries.first { $0.id == id }
    }

    func files(type: KnowledgeType) -> [KnowledgeFile] {
        entries.filter { $0.type == type }
    }

    func search(tags: Set<String>) -> [KnowledgeFile] {
        entries.filter { !$0.tags.isEmpty && !$0.tags.allSatisfy { !tags.contains($0) } }
    }
}
