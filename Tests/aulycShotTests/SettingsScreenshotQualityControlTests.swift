import AppKit
import XCTest
@testable import aulycShot

final class SettingsScreenshotQualityControlTests: XCTestCase {
    func testGeneralPaneContainsOneSharedScreenshotQualityPicker() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let qualityPickers = settingsView.descendants(of: NSPopUpButton.self).filter { popup in
            Set(popup.itemArray.compactMap { $0.representedObject as? String }) == ["original", "compressed"]
        }

        XCTAssertEqual(qualityPickers.count, 1)
    }
}

private extension NSView {
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { child -> [T] in
            let current = child as? T
            return (current.map { [$0] } ?? []) + child.descendants(of: type)
        }
    }
}
