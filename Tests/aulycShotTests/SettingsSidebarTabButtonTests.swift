import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class SettingsSidebarTabButtonTests: XCTestCase {
    func testSelectedTabKeepsATransparentBackground() {
        let button = TabButton(tab: .toolbar)

        button.isSelected = true

        XCTAssertEqual(button.layer?.backgroundColor, NSColor.clear.cgColor)
    }
}
