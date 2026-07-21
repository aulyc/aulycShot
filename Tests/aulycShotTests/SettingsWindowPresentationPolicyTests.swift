import AppKit
import XCTest
@testable import aulycShot

final class SettingsWindowPresentationPolicyTests: XCTestCase {
    func testVisibleSettingsUsesRegularApplicationWindowSemantics() {
        XCTAssertEqual(SettingsWindowPresentationPolicy.visibleActivationPolicy, .regular)
        XCTAssertEqual(SettingsWindowPresentationPolicy.windowLevel, .normal)
        XCTAssertTrue(SettingsWindowPresentationPolicy.collectionBehavior.contains(.managed))
        XCTAssertFalse(SettingsWindowPresentationPolicy.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(SettingsWindowPresentationPolicy.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    func testClosingSettingsRestoresMenuBarApplicationSemantics() {
        XCTAssertEqual(SettingsWindowPresentationPolicy.hiddenActivationPolicy, .accessory)
    }
}
