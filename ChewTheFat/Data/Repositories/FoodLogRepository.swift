import Foundation
import SwiftData

@MainActor
struct FoodLogRepository {
    let context: ModelContext
    /// Hook fired after any insert/delete so cached aggregates (e.g. `Trends`)
    /// can mark themselves stale. Optional — tests and previews leave it nil.
    var onChange: (@MainActor () -> Void)? = nil

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
        onChange?()
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

    /// True when at least one `LoggedFood` exists for the given local-day +
    /// meal type. Used by `SessionTrigger` to suppress "log breakfast" prompts
    /// after the user has already logged breakfast.
    func hasMeal(on date: Date, type: MealType) throws -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let mealRaw = type.rawValue
        var descriptor = FetchDescriptor<LoggedFood>(
            predicate: #Predicate { $0.date == day && $0.meal == mealRaw }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    /// Returns the user's most recent distinct `(meal, date)` groupings as
    /// short comma-joined food summaries — feeds the chat suggestion chips
    /// that auto-seed a `.logMeal` session. Today's date is excluded so the
    /// list is always "what you've eaten on prior days."
    func recentMealSummaries(
        type: MealType,
        limit: Int = 3,
        now: Date = .now
    ) throws -> [String] {
        precondition(limit > 0)
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let mealRaw = type.rawValue
        let descriptor = FetchDescriptor<LoggedFood>(
            predicate: #Predicate {
                $0.meal == mealRaw && $0.date < today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)

        var seenSummaries = Set<String>()
        var summaries: [String] = []
        var bucket: [LoggedFood] = []
        var bucketDay: Date?

        func flush() {
            guard !bucket.isEmpty else { return }
            let names = bucket.compactMap { $0.foodEntry?.name }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !names.isEmpty else { return }
            let summary = names.joined(separator: ", ")
            if seenSummaries.insert(summary).inserted {
                summaries.append(summary)
            }
            bucket.removeAll(keepingCapacity: true)
        }

        for row in rows {
            if bucketDay == nil { bucketDay = row.date }
            if row.date != bucketDay {
                flush()
                if summaries.count >= limit { break }
                bucketDay = row.date
            }
            bucket.append(row)
        }
        flush()
        return Array(summaries.prefix(limit))
    }

    func delete(_ entry: LoggedFood) throws {
        entry.foodEntry?.logCount = max(0, (entry.foodEntry?.logCount ?? 1) - 1)
        context.delete(entry)
        try context.save()
        onChange?()
    }
}
