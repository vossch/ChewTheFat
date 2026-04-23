import Foundation

@MainActor
struct MemoryContextSource: ContextSourceProtocol {
    let memory: MemoryRepository
    let limit: Int

    init(memory: MemoryRepository, limit: Int = 10) {
        self.memory = memory
        self.limit = limit
    }

    nonisolated var name: String { "memory" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        guard let entries = try? memory.list() else { return [] }
        let trimmed = Array(entries.prefix(limit))
        guard !trimmed.isEmpty else { return [] }
        let lines = trimmed.map { "- \($0.content)" }
        let body = "Long-term memory:\n" + lines.joined(separator: "\n")
        return [ContextFragment(label: "Memory", body: body, priority: .normal)]
    }
}
