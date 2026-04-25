import XCTest
@testable import ChewTheFat

@MainActor
final class WidgetIntentDecoderTests: XCTestCase {
    func testMealCard_roundTrip() throws {
        let intent = WidgetIntent.mealCard(MealCardPayload(
            loggedFoodIds: [UUID(), UUID()],
            mealType: .breakfast,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try assertRoundTrip(intent)
    }

    func testMacroChart_roundTrip() throws {
        let intent = WidgetIntent.macroChart(MacroChartPayload(
            date: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try assertRoundTrip(intent)
    }

    func testWeightGraph_roundTrip() throws {
        let intent = WidgetIntent.weightGraph(WeightGraphPayload(
            dateRange: .init(
                start: Date(timeIntervalSince1970: 1_699_000_000),
                end: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ))
        try assertRoundTrip(intent)
    }

    func testQuickLog_roundTrip() throws {
        let intent = WidgetIntent.quickLog(QuickLogPayload(
            candidateFoodEntryIds: [UUID()],
            prompt: "Eggs again?"
        ))
        try assertRoundTrip(intent)
    }

    func testWeightLogPrompt_roundTrip() throws {
        let intent = WidgetIntent.weightLogPrompt(WeightLogPromptPayload(
            suggestionsKg: [88.4, 88.2, 88.0, 87.8, 87.6],
            lastEntryKg: 88.0,
            preferredUnits: "metric"
        ))
        try assertRoundTrip(intent)
    }

    func testUnknownType_returnsNil() {
        let row = MessageWidget(order: 0, type: "unknownThing", payload: Data())
        XCTAssertNil(WidgetIntentDecoder.decode(row))
    }

    private func assertRoundTrip(_ intent: WidgetIntent, file: StaticString = #file, line: UInt = #line) throws {
        let payload = try JSONEncoder().encode(intent)
        // The stored row carries ONLY the payload struct — WidgetIntent's
        // outer discriminator is the MessageWidget.type column. So extract
        // the inner payload for the row.
        let row: MessageWidget
        switch intent {
        case .mealCard(let p):
            row = MessageWidget(order: 0, type: "mealCard", payload: try JSONEncoder().encode(p))
        case .macroChart(let p):
            row = MessageWidget(order: 0, type: "macroChart", payload: try JSONEncoder().encode(p))
        case .weightGraph(let p):
            row = MessageWidget(order: 0, type: "weightGraph", payload: try JSONEncoder().encode(p))
        case .weightLogPrompt(let p):
            row = MessageWidget(order: 0, type: "weightLogPrompt", payload: try JSONEncoder().encode(p))
        case .quickLog(let p):
            row = MessageWidget(order: 0, type: "quickLog", payload: try JSONEncoder().encode(p))
        }
        _ = payload
        guard let decoded = WidgetIntentDecoder.decode(row) else {
            XCTFail("decoder returned nil for \(intent.type)", file: file, line: line)
            return
        }
        XCTAssertEqual(decoded, intent, file: file, line: line)
    }
}
