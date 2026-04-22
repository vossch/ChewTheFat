import Foundation
import SwiftData

@MainActor
struct MemoryRepository {
    let context: ModelContext

    func list(category: String? = nil, limit: Int = 100) throws -> [Memory] {
        var descriptor: FetchDescriptor<Memory>
        if let category {
            descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate { $0.category == category },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Memory>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func add(content: String, category: String? = nil) throws -> Memory {
        let memory = Memory(content: content, category: category)
        context.insert(memory)
        try context.save()
        return memory
    }

    func delete(_ memory: Memory) throws {
        context.delete(memory)
        try context.save()
    }
}
