import Foundation
import SwiftData

@MainActor
struct SessionRepository {
    let context: ModelContext

    func create(goal: SessionGoal, name: String? = nil) throws -> Session {
        let resolvedName = name ?? defaultName(for: goal)
        let session = Session(name: resolvedName, goal: goal.rawValue)
        context.insert(session)
        try context.save()
        return session
    }

    func list(limit: Int = 50) throws -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func find(id: UUID) throws -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func appendMessage(
        _ message: Message,
        to session: Session
    ) throws {
        message.session = session
        if message.modelContext == nil {
            context.insert(message)
        }
        session.lastMessageAt = message.createdAt
        try context.save()
    }

    private func defaultName(for goal: SessionGoal) -> String {
        switch goal {
        case .onboarding: return "Welcome"
        case .logMeal: return "Log a meal"
        case .logWeight: return "Log weight"
        case .userInsights: return "Insights"
        case .general: return "Chat"
        }
    }
}
