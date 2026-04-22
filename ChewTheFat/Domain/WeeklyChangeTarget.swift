import Foundation

struct WeeklyChangeTarget: Hashable, Sendable, Codable {
    static let minKgPerWeek: Double = -0.7
    static let maxKgPerWeek: Double = 0.45

    let kgPerWeek: Double

    init?(kgPerWeek: Double) {
        guard kgPerWeek >= Self.minKgPerWeek, kgPerWeek <= Self.maxKgPerWeek else {
            return nil
        }
        self.kgPerWeek = kgPerWeek
    }

    static let maintenance = WeeklyChangeTarget(kgPerWeek: 0)!
}
