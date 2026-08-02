import XCTest
@testable import aulycShot

@MainActor
final class EditorInitialToolTests: XCTestCase {
    func testScreenCaptureEditorStartsWithRectangleTool() {
        guard let tool = EditWindowController.startupTool(isPresetImage: false) else {
            return XCTFail("Screen capture editor should have a startup tool")
        }

        guard case .rectangle = tool else {
            return XCTFail("Screen capture editor should start with the rectangle tool")
        }
    }

    func testPresetImageEditorKeepsNeutralStartup() {
        XCTAssertNil(EditWindowController.startupTool(isPresetImage: true))
    }
}
