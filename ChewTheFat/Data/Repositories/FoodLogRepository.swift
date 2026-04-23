import Foundation
import SwiftData

@MainActor
struct FoodLogRepository {
    let context: ModelContext

    func log(
        foodEntry: FoodEntry,
        serving: Serving,
        quantity: Double,
        meal: MealType,
        date: Date,
        message: Message? = nil
    ) throws -> LoggedFood {
        precondition(quantity > 0, "LoggedFood.quantity must be > 0")
        precondition(serving.foodEntry === foodEntry, "Serving must belong to foodEntry")

        let entry = LoggedFood(
            date: Calendar.current.startOfDay(for: date),
            meal: meal.rawValue,
            quantity: quantity,
            foodEntry: foodEntry,
            serving: serving,
            message: message
        )
        context.insert(entry)

        foodEntry.logCount += 1
        foodEntry.lastLoggedAt = .now

        try context.save()
        return entry
    }

    func loggedFoods(on date: Date) throws -> [LoggedFood] {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<LoggedFood>(
            predicate: #Predicate { $0.date == day },
            sortBy: [SortDescriptor(\.meal)]
        )
        return try context.fetch(descriptor)
    }

    func loggedFoods(in range: ClosedRange<Date>) throws -> [LoggedFood] {
        let start = Calendar.current.startOfDay(for: range.lowerBound)
        let end = Calendar.current.startOfDay(for: range.upperBound)
        let descriptor = FetchDescriptor<LoggedFood>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    func loggedFoods(ids: [UUID]) throws -> [LoggedFood] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<LoggedFood>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        return try context.fetch(descriptor)
    }

    func delete(_ entry: LoggedFood) throws {
        entry.foodEntry?.logCount = max(0, (entry.foodEntry?.logCount ?? 1) - 1)
        context.delete(entry)
        try context.save()
    }
}
