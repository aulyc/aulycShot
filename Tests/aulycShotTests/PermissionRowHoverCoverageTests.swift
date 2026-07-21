import AppKit
import XCTest
@testable import aulycShot

final class PermissionRowHoverCoverageTests: XCTestCase {
    func testPermissionRowsFillTheCardWidth() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.showPermissionsTab()
        settingsView.layoutSubtreeIfNeeded()

        let permissionRows = settingsView.descendants(of: HoverButton.self).filter {
            $0.title.isEmpty && $0.showsHoverBackground && $0.interactiveContentView == nil
        }
        XCTAssertEqual(permissionRows.count, 2)

        for row in permissionRows {
            guard let innerStack = row.superview, let card = innerStack.superview else {
                return XCTFail("Permission row hierarchy is incomplete")
            }
            XCTAssertEqual(innerStack.frame.minX, 0, accuracy: 0.5)
            XCTAssertEqual(innerStack.bounds.width, card.bounds.width, accuracy: 0.5)
            XCTAssertEqual(row.frame.minX, 0, accuracy: 0.5)
            XCTAssertEqual(row.bounds.width, card.bounds.width, accuracy: 0.5)
        }
    }

    func testBothPermissionRowsDispatchTheirMatchingSettingsRequest() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.showPermissionsTab()
        settingsView.layoutSubtreeIfNeeded()

        var requests: [RequiredPermission] = []
        settingsView.onPermissionSettingsRequest = { permission, _ in
            requests.append(permission)
        }

        let permissionRows = settingsView.descendants(of: HoverButton.self).filter {
            $0.title.isEmpty && $0.showsHoverBackground && $0.interactiveContentView == nil
        }
        XCTAssertEqual(permissionRows.count, 2)

        permissionRows.forEach { $0.performClick(nil) }

        XCTAssertEqual(requests, [.accessibility, .screenRecording])
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
