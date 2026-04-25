import XCTest
@testable import ChewTheFat

final class WeightLogSuggestionsTests: XCTestCase {
    func testFiveSuggestionsHighestFirst() {
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: 80,
            units: .metric
        )
        XCTAssertEqual(suggestions.count, 5)
        for i in 1..<suggestions.count {
            XCTAssertGreaterThan(suggestions[i - 1], suggestions[i])
        }
    }

    func testMetricCentersOnLastEntry() {
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: 80,
            units: .metric
        )
        XCTAssertEqual(suggestions[2], 80, accuracy: 0.01)
        XCTAssertEqual(suggestions[0], 80.4, accuracy: 0.01)
        XCTAssertEqual(suggestions[4], 79.6, accuracy: 0.01)
    }

    func testImperialUsesDisplayUnitStep() {
        // 194.6 lb ≈ 88.267 kg. Step 0.2 lb in display → 0.0907 kg each way.
        let lastKg = UnitFormatter.weightToKg(194.6, from: .imperial)
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: lastKg,
            units: .imperial
        )
        XCTAssertEqual(suggestions.count, 5)
        let topDisplay = UnitFormatter.weightValue(kg: suggestions[0], in: .imperial)
        let middleDisplay = UnitFormatter.weightValue(kg: suggestions[2], in: .imperial)
        let bottomDisplay = UnitFormatter.weightValue(kg: suggestions[4], in: .imperial)
        XCTAssertEqual(topDisplay, 195.0, accuracy: 0.01)
        XCTAssertEqual(middleDisplay, 194.6, accuracy: 0.01)
        XCTAssertEqual(bottomDisplay, 194.2, accuracy: 0.01)
    }

    func testNilLastEntryFallsBackToBaseline() {
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: nil,
            units: .metric
        )
        XCTAssertEqual(suggestions[2], WeightLogSuggestions.fallbackKg, accuracy: 0.01)
    }
}
