import Foundation
import SwiftData

@MainActor
struct WeightLogRepository {
    let context: ModelContext
    var onChange: (@MainActor () -> Void)? = nil

    func log(
        weightKg: Double,
        date: Date,
        message: Message? = nil
    ) throws -> WeightEntry {
        precondition(weightKg > 0 && weightKg < 500, "WeightEntry.weightKg out of range")
        let entry = WeightEntry(
            date: Calendar.current.startOfDay(for: date),
            weightKg: weightKg,
            message: message
        )
        context.insert(entry)
        try context.save()
        onChange?()
        return entry
    }

    func entries(in range: ClosedRange<Date>) throws -> [WeightEntry] {
        let start = Calendar.current.startOfDay(for: range.lowerBound)
        let end = Calendar.current.startOfDay(for: range.upperBound)
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    func latest() throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
