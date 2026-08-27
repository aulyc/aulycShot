import XCTest
@testable import aulycShot

final class AgentArgumentParsingTests: XCTestCase {
    func testCursorPreservesFlagEqualsAndSeparateValueForms() throws {
        var cursor = AgentArgumentCursor([
            "--pretty",
            "--out=result.png",
            "-s",
            "marks.json"
        ])

        XCTAssertEqual(
            try cursor.next(flags: ["--pretty"]),
            .flag("--pretty")
        )
        XCTAssertEqual(
            try cursor.next(flags: ["--pretty"]),
            .option(key: "--out", value: "result.png")
        )
        XCTAssertEqual(
            try cursor.next(flags: ["--pretty"]),
            .option(key: "-s", value: "marks.json")
        )
        XCTAssertNil(try cursor.next(flags: ["--pretty"]))
    }

    func testCursorRecognizesOnlyExactHelpTokens() throws {
        var cursor = AgentArgumentCursor(["--help", "-h"])

        XCTAssertEqual(try cursor.next(flags: []), .help)
        XCTAssertEqual(try cursor.next(flags: []), .help)
        XCTAssertNil(try cursor.next(flags: []))
    }

    func testCaptureScreenKeepsIgnoringAnUnrelatedRectOption() throws {
        let options = try AgentCaptureOptions.parse([
            "--target", "screen",
            "--rect", "1,2,300,200",
            "--out", "shot.png"
        ])

        guard case .screen(let screenIndex, let displayID) = options.target else {
            return XCTFail("Expected screen target")
        }
        XCTAssertNil(screenIndex)
        XCTAssertNil(displayID)
    }

    func testPrettyEqualsKeepsCurrentUnknownOptionError() {
        assertUsageError("Unknown option --pretty") {
            try AgentCaptureOptions.parse([
                "--pretty=true",
                "--out", "shot.png"
            ])
        }
    }

    func testWindowsParserKeepsAllValuelessFlags() throws {
        let options = try AgentWindowsOptions.parse([
            "--pretty",
            "--frontmost-only",
            "--include-system"
        ])

        XCTAssertTrue(options.pretty)
        XCTAssertTrue(options.frontmostOnly)
        XCTAssertTrue(options.includeSystem)
    }

    func testRunParserKeepsEqualsAndSeparateValueForms() throws {
        let options = try AgentRunOptions.parse([
            "--spec=marks.json",
            "-o", "result.png",
            "--pretty"
        ])

        XCTAssertEqual(options.specURL.lastPathComponent, "marks.json")
        XCTAssertEqual(options.outputURL.lastPathComponent, "result.png")
        XCTAssertTrue(options.pretty)
    }

    func testAnnotateParserKeepsAliasesAndPrettyFlag() throws {
        let options = try AgentAnnotateOptions.parse([
            "-i", "input.png",
            "--spec=marks.json",
            "--output", "result.png",
            "--pretty"
        ])

        XCTAssertEqual(options.inputURL.lastPathComponent, "input.png")
        XCTAssertEqual(options.specURL.lastPathComponent, "marks.json")
        XCTAssertEqual(options.outputURL.lastPathComponent, "result.png")
        XCTAssertTrue(options.pretty)
    }

    func testRectParserAcceptsFinitePositiveGeometry() throws {
        XCTAssertEqual(
            try AgentCaptureOptions.parseRect("-10.5, 20.25, 300, 200"),
            CGRect(x: -10.5, y: 20.25, width: 300, height: 200)
        )
    }

    func testRectParserRejectsNonFiniteCoordinatesAndDimensions() {
        for value in [
            "nan,0,100,100",
            "0,inf,100,100",
            "0,0,nan,100",
            "0,0,100,-inf"
        ] {
            assertUsageError("Invalid rect \(value)") {
                try AgentCaptureOptions.parseRect(value)
            }
        }
    }

    func testRectParserRejectsZeroAndNegativeDimensions() {
        for value in ["0,0,0,100", "0,0,100,0", "0,0,-1,100", "0,0,100,-1"] {
            assertUsageError("Invalid rect \(value)") {
                try AgentCaptureOptions.parseRect(value)
            }
        }
    }

    func testWindowIDParserAcceptsPositiveUInt32Boundaries() throws {
        XCTAssertEqual(try AgentCaptureOptions.parseWindowID("1"), 1)
        XCTAssertEqual(try AgentCaptureOptions.parseWindowID("4294967295"), UInt32.max)
    }

    func testWindowIDParserRejectsZeroNegativeOverflowAndText() {
        for value in ["0", "-1", "4294967296", "window"] {
            assertUsageError("Invalid window id \(value)") {
                try AgentCaptureOptions.parseWindowID(value)
            }
        }
    }

    func testDisplayIDParserAcceptsPositiveUInt32Boundaries() throws {
        XCTAssertEqual(try AgentCaptureOptions.parseDisplayID("1"), 1)
        XCTAssertEqual(try AgentCaptureOptions.parseDisplayID("4294967295"), UInt32.max)
    }

    func testDisplayIDParserRejectsZeroNegativeOverflowAndText() {
        for value in ["0", "-1", "4294967296", "display"] {
            assertUsageError("Invalid display id \(value)") {
                try AgentCaptureOptions.parseDisplayID(value)
            }
        }
    }

    func testScreenIndexAcceptsZeroBoundary() throws {
        let options = try AgentCaptureOptions.parse([
            "--target", "screen",
            "--screen-index", "0",
            "--out", "shot.png"
        ])

        guard case .screen(let screenIndex, let displayID) = options.target else {
            return XCTFail("Expected screen target")
        }
        XCTAssertEqual(screenIndex, 0)
        XCTAssertNil(displayID)
    }

    func testScreenIndexRejectsNegativeAndNonNumericValues() {
        for value in ["-1", "screen"] {
            assertUsageError("Invalid screen index \(value)") {
                try AgentCaptureOptions.parse([
                    "--target", "screen",
                    "--screen-index", value,
                    "--out", "shot.png"
                ])
            }
        }
    }

    func testWindowLimitAcceptsOneAndIntMaximum() throws {
        XCTAssertEqual(try AgentWindowsOptions.parse(["--limit", "1"]).limit, 1)
        XCTAssertEqual(
            try AgentWindowsOptions.parse(["--limit", String(Int.max)]).limit,
            Int.max
        )
    }

    func testWindowLimitRejectsZeroNegativeAndOverflowValues() {
        for value in ["0", "-1", "999999999999999999999999"] {
            assertUsageError("Invalid limit \(value)") {
                try AgentWindowsOptions.parse(["--limit", value])
            }
        }
    }

    func testRunParserRejectsRawAndAnnotatedOutputPathConflict() {
        assertUsageError("--shot-out must be different from --out") {
            try AgentRunOptions.parse([
                "--spec", "marks.json",
                "--out", "result.png",
                "--shot-out", "result.png"
            ])
        }
    }

    private func assertUsageError<T>(
        _ expectedMessage: String,
        operation: () throws -> T
    ) {
        do {
            _ = try operation()
            XCTFail("Expected usage error")
        } catch AgentCLIError.usage(let message) {
            XCTAssertEqual(message, expectedMessage)
        } catch {
            XCTFail("Expected usage error, got \(error)")
        }
    }
}
