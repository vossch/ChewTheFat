import Foundation

protocol FoodReferenceSource: Sendable {
    var source: FoodSource { get }
    func search(query: String, limit: Int) async throws -> [ReferenceFood]
}
