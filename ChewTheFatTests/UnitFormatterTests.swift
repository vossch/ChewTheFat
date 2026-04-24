import XCTest
@testable import ChewTheFat

final class UnitFormatterTests: XCTestCase {
    func testWeightKgRoundTripsMetric() {
        XCTAssertEqual(UnitFormatter.weight(kg: 82.5, in: .metric), "82.5 kg")
    }

    func testWeightKgConvertsToLbs() {
        // 82.5 kg ≈ 181.9 lb
        let formatted = UnitFormatter.weight(kg: 82.5, in: .imperial)
        XCTAssertTrue(formatted.hasSuffix(" lb"))
        let value = Double(formatted.replacingOccurrences(of: " lb", with: ""))!
        XCTAssertEqual(value, 181.9, accuracy: 0.1)
    }

    func testWeightKgRoundTripThroughImperial() {
        let kg = 82.5
        let imperial = UnitFormatter.weightValue(kg: kg, in: .imperial)
        let backToKg = UnitFormatter.weightToKg(imperial, from: .imperial)
        XCTAssertEqual(backToKg, kg, accuracy: 0.0001)
    }

    func testHeightCmMetric() {
        XCTAssertEqual(UnitFormatter.height(cm: 180, in: .metric), "180 cm")
    }

    func testHeightCmImperial() {
        // 180 cm ≈ 70.87 in → 5'11"
        XCTAssertEqual(UnitFormatter.height(cm: 180, in: .imperial), "5′11″")
    }

    func testHeightCmImperialExactFeet() {
        // 152.4 cm = 5'0"
        XCTAssertEqual(UnitFormatter.height(cm: 152.4, in: .imperial), "5′0″")
    }

    func testHeightCmImperialBoundaryNoTwelveInches() {
        // 182.88 cm = 72 inches exactly = 6'0", never 5'12".
        XCTAssertEqual(UnitFormatter.height(cm: 182.88, in: .imperial), "6′0″")
    }

    func testPreferredUnitSystemFromStored() {
        XCTAssertEqual(PreferredUnitSystem(storedValue: "imperial"), .imperial)
        XCTAssertEqual(PreferredUnitSystem(storedValue: "metric"), .metric)
        XCTAssertEqual(PreferredUnitSystem(storedValue: nil), .metric)
        XCTAssertEqual(PreferredUnitSystem(storedValue: ""), .metric)
    }

    func testGramsAndCalories() {
        XCTAssertEqual(UnitFormatter.grams(42.3, fractionDigits: 0), "42 g")
        XCTAssertEqual(UnitFormatter.calories(1800), "1800 kcal")
    }

    func testWeightUnitLabel() {
        XCTAssertEqual(UnitFormatter.weightUnitLabel(.metric), "kg")
        XCTAssertEqual(UnitFormatter.weightUnitLabel(.imperial), "lb")
    }
}
