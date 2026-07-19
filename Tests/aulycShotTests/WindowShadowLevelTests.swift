import XCTest
@testable import aulycShot

final class WindowShadowLevelTests: XCTestCase {
    func testLegacyDisabledSettingStaysDisabled() {
        XCTAssertEqual(
            WindowShadowLevel.resolve(legacyEnabled: false, legacySize: 60),
            .disabled
        )
    }

    func testLegacySliderValuesMapToNearestLevel() {
        XCTAssertEqual(WindowShadowLevel.resolve(legacyEnabled: true, legacySize: 6), .small)
        XCTAssertEqual(WindowShadowLevel.resolve(legacyEnabled: true, legacySize: 22), .medium)
        XCTAssertEqual(WindowShadowLevel.resolve(legacyEnabled: true, legacySize: 60), .large)
    }

    func testEnabledLevelsUseIncreasingShadowSizes() {
        XCTAssertLessThan(WindowShadowLevel.small.shadowSize, WindowShadowLevel.medium.shadowSize)
        XCTAssertLessThan(WindowShadowLevel.medium.shadowSize, WindowShadowLevel.large.shadowSize)
    }
}
