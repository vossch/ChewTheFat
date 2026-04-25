import XCTest
@testable import ChewTheFat

@MainActor
final class WeightLogPromptViewModelTests: XCTestCase {
    private func makePayload(
        lastEntryKg: Double? = 88.267,
        units: PreferredUnitSystem = .imperial
    ) -> WeightLogPromptPayload {
        let suggestions = WeightLogSuggestions.aroundLatest(
            lastEntryKg: lastEntryKg,
            units: units
        )
        return WeightLogPromptPayload(
            suggestionsKg: suggestions,
            lastEntryKg: lastEntryKg,
            preferredUnits: units.rawValue
        )
    }

    func testMiddleOptionMarkedSameAsYesterday() {
        let vm = WeightLogPromptViewModel(payload: makePayload())
        XCTAssertEqual(vm.options.count, 5)
        XCTAssertTrue(vm.options[2].isSameAsLast)
        XCTAssertTrue(vm.options[2].label.contains("Same as yesterday"))
    }

    func testReplyTextFormatsWithUnitLabel() {
        let vm = WeightLogPromptViewModel(payload: makePayload())
        let reply = vm.replyText(for: vm.options[2])
        XCTAssertEqual(reply, "194.6 lb")
    }

    func testMetricReplyUsesKg() {
        let vm = WeightLogPromptViewModel(payload: makePayload(lastEntryKg: 80, units: .metric))
        XCTAssertEqual(vm.replyText(for: vm.options[2]), "80.0 kg")
    }

    func testMarkCollapsedSetsFlag() {
        let vm = WeightLogPromptViewModel(payload: makePayload())
        XCTAssertFalse(vm.isCollapsed)
        vm.markCollapsed()
        XCTAssertTrue(vm.isCollapsed)
    }

    func testNilLastEntryDoesNotMarkAnyOption() {
        let vm = WeightLogPromptViewModel(payload: makePayload(lastEntryKg: nil, units: .metric))
        XCTAssertFalse(vm.options.contains(where: \.isSameAsLast))
    }
}
