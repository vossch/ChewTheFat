import Foundation
import SwiftData

@Model
final class Trends {
    @Attribute(.unique) var id: UUID
    var updatedAt: Date
    var isStale: Bool
    var weightRangeStart: Date?
    var weightRangeEnd: Date?
    var weightTrendPayload: Data?
    var macroRangeStart: Date?
    var macroRangeEnd: Date?
    var macroTrendPayload: Data?

    init(
        id: UUID = UUID(),
        updatedAt: Date = .now,
        isStale: Bool = true,
        weightRangeStart: Date? = nil,
        weightRangeEnd: Date? = nil,
        weightTrendPayload: Data? = nil,
        macroRangeStart: Date? = nil,
        macroRangeEnd: Date? = nil,
        macroTrendPayload: Data? = nil
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.isStale = isStale
        self.weightRangeStart = weightRangeStart
        self.weightRangeEnd = weightRangeEnd
        self.weightTrendPayload = weightTrendPayload
        self.macroRangeStart = macroRangeStart
        self.macroRangeEnd = macroRangeEnd
        self.macroTrendPayload = macroTrendPayload
    }
}
