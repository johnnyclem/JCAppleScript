import XCTest
@testable import JCAppleScript

final class AppleScriptEngineTests: XCTestCase {
    let engine = AppleScriptEngine(defaultTimeout: 10)

    // MARK: - Variable Substitution

    func testVariableSubstitution() {
        let result = AppleScriptEngine.substituteVariables(
            in: "display dialog \"$0 says $1\"",
            with: ["Alice", "hello"]
        )
        XCTAssertEqual(result, "display dialog \"Alice says hello\"")
    }

    func testVariableSubstitutionDoubleDigitOrdering() {
        // $1 must not corrupt $10 / $11.
        let vars = (0...10).map { "v\($0)" }
        let result = AppleScriptEngine.substituteVariables(in: "$10 $1 $0", with: vars)
        XCTAssertEqual(result, "v10 v1 v0")
    }

    // MARK: - Language inference

    func testLanguageInference() {
        XCTAssertEqual(AppleScriptEngine.inferLanguage(fromPath: "/tmp/a.js"), .javaScript)
        XCTAssertEqual(AppleScriptEngine.inferLanguage(fromPath: "/tmp/a.JXA"), .javaScript)
        XCTAssertEqual(AppleScriptEngine.inferLanguage(fromPath: "/tmp/a.applescript"), .appleScript)
        XCTAssertEqual(AppleScriptEngine.inferLanguage(fromPath: "/tmp/a.scpt"), .appleScript)
    }

    // MARK: - Error parsing

    func testParseErrorNumber() {
        XCTAssertEqual(AppleScriptEngine.parseErrorNumber(from: "syntax error: blah (-2741)"), -2741)
        XCTAssertNil(AppleScriptEngine.parseErrorNumber(from: "no number here"))
    }

    func testScriptResultInit() {
        let result = ScriptResult(output: "hello", success: true, errorMessage: nil)
        XCTAssertEqual(result.output, "hello")
        XCTAssertTrue(result.success)
        XCTAssertNil(result.errorMessage)
    }

    func testScriptResultWithError() {
        let result = ScriptResult(output: "", success: false, errorMessage: "Something went wrong")
        XCTAssertEqual(result.output, "")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorMessage, "Something went wrong")
    }

    // MARK: - Error Types

    func testScriptErrorDescriptions() {
        let errors: [ScriptError] = [
            .scriptCompilationFailed(message: "syntax error", errorNumber: 2741),
            .scriptExecutionFailed(message: "app not found", errorNumber: nil),
            .fileNotFound(path: "/tmp/missing.scpt"),
            .invalidScriptSource,
            .processExecutionFailed(exitCode: 1, stderr: "oops"),
            .timeout,
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }

        // Spot check specific messages
        XCTAssertTrue(ScriptError.timeout.localizedDescription.contains("timed out"))
        XCTAssertTrue(ScriptError.fileNotFound(path: "/foo").localizedDescription.contains("/foo"))
    }

    // MARK: - Engine Initialization

    func testDefaultEngineTimeout() {
        let defaultEngine = AppleScriptEngine()
        XCTAssertEqual(defaultEngine.defaultTimeout, 30)
    }

    func testCustomTimeout() {
        let customEngine = AppleScriptEngine(defaultTimeout: 60)
        XCTAssertEqual(customEngine.defaultTimeout, 60)
    }

    func testSharedInstance() {
        let shared = AppleScriptEngine.shared
        XCTAssertEqual(shared.defaultTimeout, 30)
    }

    // MARK: - File Not Found

    func testExecuteFileNotFound() {
        XCTAssertThrowsError(try engine.executeFile(at: "/nonexistent/path.scpt")) { error in
            guard case ScriptError.fileNotFound = error else {
                XCTFail("Expected fileNotFound error, got \(error)")
                return
            }
        }
    }
}
