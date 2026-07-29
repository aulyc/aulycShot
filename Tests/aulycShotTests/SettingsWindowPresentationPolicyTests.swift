import AppKit
import Carbon.HIToolbox
import XCTest
@testable import aulycShot

final class SettingsWindowPresentationPolicyTests: XCTestCase {
    func testVisibleSettingsKeepsMenuBarApplicationSemantics() {
        XCTAssertEqual(SettingsWindowPresentationPolicy.visibleActivationPolicy, .accessory)
        XCTAssertEqual(SettingsWindowPresentationPolicy.windowLevel, .normal)
        XCTAssertTrue(SettingsWindowPresentationPolicy.collectionBehavior.contains(.managed))
        XCTAssertFalse(SettingsWindowPresentationPolicy.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(SettingsWindowPresentationPolicy.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    func testClosingSettingsRestoresMenuBarApplicationSemantics() {
        XCTAssertEqual(SettingsWindowPresentationPolicy.hiddenActivationPolicy, .accessory)
    }

    func testBareEscapeClosesSettingsWindow() {
        XCTAssertTrue(
            SettingsWindowPresentationPolicy.shouldCloseForEscape(
                keyCode: UInt16(kVK_Escape),
                modifiers: []
            )
        )
        XCTAssertFalse(
            SettingsWindowPresentationPolicy.shouldCloseForEscape(
                keyCode: UInt16(kVK_Escape),
                modifiers: .command
            )
        )
        XCTAssertFalse(
            SettingsWindowPresentationPolicy.shouldCloseForEscape(
                keyCode: UInt16(kVK_Return),
                modifiers: []
            )
        )
    }
}
