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

    func testScreenshotExecutionLabelsDescribeExecutionSemantics() throws {
        let zh = try localization(for: "zh-Hans")
        let en = try localization(for: "en")

        XCTAssertEqual(zh["clipboardShortcutHeader"], "触发截图执行")
        XCTAssertEqual(zh["screenshotOutputActionLabel"], "截图执行后")
        XCTAssertEqual(zh["tipConfirm"], "触发截图执行")
        XCTAssertEqual(zh["shortcutDefaultDisplay"], "未设置")
        XCTAssertEqual(zh["clipboardShortcutDefaultDisplay"], "未设置")
        XCTAssertFalse(try XCTUnwrap(zh["shortcutHint"]).contains("双击"))
        XCTAssertFalse(try XCTUnwrap(zh["clipboardShortcutHint"]).contains("双击"))
        XCTAssertNil(zh["fileSaveShortcutHeader"])
        XCTAssertNil(zh["fileSaveShortcutHint"])

        XCTAssertEqual(en["clipboardShortcutHeader"], "Execute Screenshot")
        XCTAssertEqual(en["screenshotOutputActionLabel"], "After screenshot execution")
        XCTAssertEqual(en["tipConfirm"], "Execute Screenshot")
        XCTAssertEqual(en["shortcutDefaultDisplay"], "Not set")
        XCTAssertEqual(en["clipboardShortcutDefaultDisplay"], "Not set")
        XCTAssertFalse(try XCTUnwrap(en["shortcutHint"]).localizedCaseInsensitiveContains("double-tap"))
        XCTAssertFalse(try XCTUnwrap(en["clipboardShortcutHint"]).localizedCaseInsensitiveContains("double-tap"))
        XCTAssertNil(en["fileSaveShortcutHeader"])
        XCTAssertNil(en["fileSaveShortcutHint"])
    }

    func testImageStitchingToolCopyIsConsistent() throws {
        let zh = try localization(for: "zh-Hans")
        let en = try localization(for: "en")

        XCTAssertEqual(zh["imageMergeShortcutHeader"], "图片拼接工具")
        XCTAssertEqual(zh["mergeImages"], "图片拼接工具")
        XCTAssertEqual(zh["imageMergeWindowTitle"], "图片拼接工具")
        XCTAssertEqual(
            zh["shortcutConflictImageMerge"],
            "该按键组合已被图片拼接工具快捷键占用，请换一个"
        )
        XCTAssertEqual(zh["mergeEditExitHint"], "正在编辑拼接结果，按 X 退出编辑")
        XCTAssertEqual(zh["imageMergeNeedTwoImages"], "请选择至少两张 Finder 图片进行拼接")
        XCTAssertEqual(zh["imageMergeFailed"], "图片拼接失败")
        XCTAssertEqual(zh["imageMergeSaved"], "拼接结果已保存")
        XCTAssertEqual(zh["imageMergeEmptyTitle"], "拖入图片开始拼接")
        XCTAssertEqual(zh["imageMergeCornerRadius"], "边角")

        XCTAssertEqual(en["imageMergeShortcutHeader"], "Image Stitching Tool")
        XCTAssertEqual(en["mergeImages"], "Image Stitching Tool")
        XCTAssertEqual(en["imageMergeWindowTitle"], "Image Stitching Tool")
        XCTAssertEqual(
            en["shortcutConflictImageMerge"],
            "This key combination is already used by the Image Stitching Tool shortcut. Please choose a different one"
        )
        XCTAssertEqual(en["mergeEditExitHint"], "Editing stitched image. Press X to exit editing")
        XCTAssertEqual(en["imageMergeNeedTwoImages"], "Select at least two Finder images to stitch")
        XCTAssertEqual(en["imageMergeFailed"], "Image stitching failed")
        XCTAssertEqual(en["imageMergeSaved"], "Stitched image saved")
        XCTAssertEqual(en["imageMergeEmptyTitle"], "Drop images to start stitching")
        XCTAssertEqual(en["imageMergeCornerRadius"], "Corners")
    }

    private func localization(for language: String) throws -> [String: String] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceURL = repositoryRoot
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(language).lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: resourceURL)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )
    }
}
