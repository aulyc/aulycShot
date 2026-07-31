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

    func testAcknowledgementsIncludeCommunitiesToolsAndProjectInspiration() throws {
        let zh = try localization(for: "zh-Hans")
        let en = try localization(for: "en")

        XCTAssertEqual(zh["aboutAcknowledgementFirst"], "1. 感谢伟大的 AI 时代，让更多想法得以更快成为现实")
        XCTAssertEqual(zh["aboutAcknowledgementSecond"], "2. 致敬 Codex 与 Claude，在创作与开发中持续并肩协作")
        XCTAssertEqual(zh["aboutAcknowledgementThird"], "3. 感谢 Linux.do 社区在测试、反馈与讨论中的支持")
        XCTAssertEqual(zh["aboutAcknowledgementFourth"], "4. 感谢每一位提交需求、报告问题和提出改进建议的用户")
        XCTAssertEqual(zh["aboutAcknowledgementFifth"], "5. 感谢开源社区与开发工具带来的启发和帮助")
        XCTAssertEqual(zh["aboutAcknowledgementSixth"], "6. 感谢 aulyc 一路以来的坚持与灵感")

        XCTAssertEqual(en["aboutAcknowledgementFirst"], "1. Thanks to the remarkable age of AI for helping more ideas become reality faster")
        XCTAssertEqual(en["aboutAcknowledgementSecond"], "2. A tribute to Codex and Claude for their continued partnership in creation and development")
        XCTAssertEqual(en["aboutAcknowledgementThird"], "3. Thanks to the Linux.do community for testing, feedback, and discussion")
        XCTAssertEqual(en["aboutAcknowledgementFourth"], "4. Thanks to everyone who submits requests, reports issues, and suggests improvements")
        XCTAssertEqual(en["aboutAcknowledgementFifth"], "5. Thanks to the open-source community and developer tools for inspiration and support")
        XCTAssertEqual(en["aboutAcknowledgementSixth"], "6. Thanks to aulyc for the persistence and inspiration behind this journey")
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
