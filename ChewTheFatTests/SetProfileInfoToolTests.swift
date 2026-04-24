import XCTest
@testable import ChewTheFat

@MainActor
final class SetProfileInfoToolTests: XCTestCase {
    func testHeightInputImperialIsParsed() async throws {
        let env = try InMemoryEnvironment()
        let tool = SetProfileInfoTool(profile: env.profile)
        let args = ToolArguments(json: #"{"heightInput":"5'11\""}"#)

        _ = try await tool.invoke(args)

        let saved = try env.profile.current()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.heightCm ?? 0, 180.34, accuracy: 0.01)
    }

    func testHeightInputCentimetersIsParsed() async throws {
        let env = try InMemoryEnvironment()
        let tool = SetProfileInfoTool(profile: env.profile)
        let args = ToolArguments(json: #"{"heightInput":"180 cm"}"#)

        _ = try await tool.invoke(args)

        XCTAssertEqual(try env.profile.current()?.heightCm, 180)
    }

    func testHeightInputUnparseableThrows() async throws {
        let env = try InMemoryEnvironment()
        let tool = SetProfileInfoTool(profile: env.profile)
        let args = ToolArguments(json: #"{"heightInput":"quite tall"}"#)

        do {
            _ = try await tool.invoke(args)
            XCTFail("expected invalidArguments error")
        } catch let error as ToolError {
            if case .invalidArguments(let detail) = error {
                XCTAssertTrue(detail.contains("quite tall"), "detail: \(detail)")
            } else {
                XCTFail("unexpected ToolError: \(error)")
            }
        }
    }

    func testHeightCmStillWorksWithoutHeightInput() async throws {
        let env = try InMemoryEnvironment()
        let tool = SetProfileInfoTool(profile: env.profile)
        let args = ToolArguments(json: #"{"heightCm":182.5}"#)

        _ = try await tool.invoke(args)

        XCTAssertEqual(try env.profile.current()?.heightCm, 182.5)
    }
}
