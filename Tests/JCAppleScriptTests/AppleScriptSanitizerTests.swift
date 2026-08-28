import XCTest
@testable import JCAppleScript

final class AppleScriptSanitizerTests: XCTestCase {

    // MARK: - Escaping

    func testEscapePlainStringUnchanged() {
        XCTAssertEqual(AppleScriptString.escape("Hello, World"), "Hello, World")
    }

    func testEscapeDoubleQuotes() {
        XCTAssertEqual(AppleScriptString.escape("say \"hi\""), "say \\\"hi\\\"")
    }

    func testEscapeBackslashes() {
        XCTAssertEqual(AppleScriptString.escape("C:\\path"), "C:\\\\path")
    }

    func testEscapeBackslashBeforeQuote() {
        // \" must become \\\" (escaped backslash + escaped quote), not \\"
        XCTAssertEqual(AppleScriptString.escape("\\\""), "\\\\\\\"")
    }

    func testEscapeNewlinesAndTabs() {
        XCTAssertEqual(AppleScriptString.escape("a\nb\rc\td"), "a\\nb\\rc\\td")
    }

    func testEscapePreventsStringBreakout() {
        // A classic injection payload cannot close the string literal:
        // every double quote in the output is preceded by a backslash.
        let payload = "x\" \ndo shell script \"rm -rf ~\" --"
        let escaped = AppleScriptString.escape(payload)
        XCTAssertFalse(escaped.contains("\n"))
        var previous: Character = " "
        for char in escaped {
            if char == "\"" {
                XCTAssertEqual(previous, "\\", "Unescaped quote in: \(escaped)")
            }
            // A backslash that escapes another character is itself consumed.
            previous = (previous == "\\" && char == "\\") ? " " : char
        }
    }

    func testQuoted() {
        XCTAssertEqual(AppleScriptString.quoted("hi"), "\"hi\"")
        XCTAssertEqual(AppleScriptString.quoted("a\"b"), "\"a\\\"b\"")
    }

    // MARK: - Integer validation

    func testIntegerValid() {
        XCTAssertEqual(AppleScriptString.integer("42"), "42")
        XCTAssertEqual(AppleScriptString.integer("-7"), "-7")
        XCTAssertEqual(AppleScriptString.integer(" 10 "), "10")
    }

    func testIntegerRejectsInjection() {
        XCTAssertNil(AppleScriptString.integer("1 of front window\ndo shell script \"evil\""))
        XCTAssertNil(AppleScriptString.integer("1; rm"))
        XCTAssertNil(AppleScriptString.integer(""))
        XCTAssertNil(AppleScriptString.integer("3.5"))
    }

    // MARK: - Boolean normalization

    func testBooleanNormalization() {
        XCTAssertEqual(AppleScriptString.boolean("true"), "true")
        XCTAssertEqual(AppleScriptString.boolean("TRUE"), "true")
        XCTAssertEqual(AppleScriptString.boolean("yes"), "true")
        XCTAssertEqual(AppleScriptString.boolean("1"), "true")
        XCTAssertEqual(AppleScriptString.boolean("false"), "false")
        XCTAssertEqual(AppleScriptString.boolean("No"), "false")
        XCTAssertEqual(AppleScriptString.boolean("0"), "false")
    }

    func testBooleanRejectsInjection() {
        XCTAssertNil(AppleScriptString.boolean("true\ndo shell script \"evil\""))
        XCTAssertNil(AppleScriptString.boolean("maybe"))
    }
}
