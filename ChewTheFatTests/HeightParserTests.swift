import XCTest
@testable import ChewTheFat

final class HeightParserTests: XCTestCase {
    func testFeetInchesStraightQuotes() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5'11\"")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5' 11\"")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5'11")), 180.34, accuracy: 0.01)
    }

    func testFeetInchesSmartQuotes() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5\u{2019}11\u{201D}")), 180.34, accuracy: 0.01)
    }

    func testFeetOnly() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5 ft")), 152.40, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5'")), 152.40, accuracy: 0.01)
    }

    func testFeetInchesDashAndSlash() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5-11")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5/11")), 180.34, accuracy: 0.01)
    }

    func testFeetInchesWords() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5 ft 11 in")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5 feet 11 inches")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5ft11in")), 180.34, accuracy: 0.01)
    }

    func testCentimeters() {
        XCTAssertEqual(HeightParser.parseCentimeters("180 cm"), 180)
        XCTAssertEqual(HeightParser.parseCentimeters("180cm"), 180)
        XCTAssertEqual(HeightParser.parseCentimeters("182.5 centimeters"), 182.5)
    }

    func testMeters() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("1.8 m")), 180, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("1.82m")), 182, accuracy: 0.01)
    }

    func testInchesOnly() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("71 in")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("71 inches")), 180.34, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("71\"")), 180.34, accuracy: 0.01)
    }

    func testBareCentimeterNumber() {
        XCTAssertEqual(HeightParser.parseCentimeters("180"), 180)
        XCTAssertEqual(HeightParser.parseCentimeters("150"), 150)
    }

    func testBareFeetNumber() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5")), 152.40, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("6")), 182.88, accuracy: 0.01)
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(HeightParser.parseCentimeters(""))
        XCTAssertNil(HeightParser.parseCentimeters("tall"))
        XCTAssertNil(HeightParser.parseCentimeters("5'15\"")) // inches > 11
        XCTAssertNil(HeightParser.parseCentimeters("50 cm")) // below min
        XCTAssertNil(HeightParser.parseCentimeters("300 cm")) // above max
    }

    func testCaseInsensitive() throws {
        XCTAssertEqual(try XCTUnwrap(HeightParser.parseCentimeters("5 FT 11 IN")), 180.34, accuracy: 0.01)
        XCTAssertEqual(HeightParser.parseCentimeters("180 CM"), 180)
    }
}
