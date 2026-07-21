import XCTest
@testable import aulycShot

final class AppLanguageTests: XCTestCase {
    func testOnlySimplifiedChineseAndEnglishAreAvailable() {
        XCTAssertEqual(AppLanguage.allCases, [.zh, .en])
    }

    func testSupportedLanguagesResolveToTheirResourceBundles() {
        XCTAssertEqual(AppLanguage.zh.lprojName, "zh-Hans")
        XCTAssertEqual(AppLanguage.en.lprojName, "en")
    }
}
