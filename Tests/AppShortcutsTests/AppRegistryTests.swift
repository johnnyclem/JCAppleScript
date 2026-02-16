import XCTest
@testable import AppShortcuts

final class AppRegistryTests: XCTestCase {
    // MARK: - Registry Setup

    func testSharedRegistryHasBuiltInApps() {
        let registry = AppRegistry.shared
        XCTAssertFalse(registry.allApps.isEmpty)
    }

    func testAllBuiltInAppsRegistered() {
        let registry = AppRegistry.shared
        let appNames = Set(registry.allApps.map { $0.appName })

        let expectedApps = [
            "Messages", "Reminders", "Finder", "Safari",
            "Mail", "Calendar", "Notes", "Music",
            "Terminal", "System Settings",
        ]

        for name in expectedApps {
            XCTAssertTrue(appNames.contains(name), "Missing app: \(name)")
        }
    }

    // MARK: - Lookup

    func testAppLookupByName() {
        let registry = AppRegistry.shared

        let messages = registry.app(named: "Messages")
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.appName, "Messages")

        // Case insensitive
        let finder = registry.app(named: "finder")
        XCTAssertNotNil(finder)
        XCTAssertEqual(finder?.appName, "Finder")
    }

    func testAppLookupByCategory() {
        let registry = AppRegistry.shared

        let commApps = registry.apps(in: .communication)
        let commNames = commApps.map { $0.appName }
        XCTAssertTrue(commNames.contains("Messages"))
        XCTAssertTrue(commNames.contains("Mail"))

        let prodApps = registry.apps(in: .productivity)
        let prodNames = prodApps.map { $0.appName }
        XCTAssertTrue(prodNames.contains("Reminders"))
        XCTAssertTrue(prodNames.contains("Calendar"))
        XCTAssertTrue(prodNames.contains("Notes"))
    }

    func testAppSearch() {
        let registry = AppRegistry.shared

        let results = registry.search("email")
        XCTAssertTrue(results.contains { $0.appName == "Mail" })

        let musicResults = registry.search("music")
        XCTAssertTrue(musicResults.contains { $0.appName == "Music" })
    }

    // MARK: - Command Lookup

    func testCommandLookupByID() {
        let registry = AppRegistry.shared

        let sendCmd = registry.command(withID: "messages.send_message")
        XCTAssertNotNil(sendCmd)
        XCTAssertEqual(sendCmd?.name, "Send Message")

        let createReminder = registry.command(withID: "reminders.create_reminder")
        XCTAssertNotNil(createReminder)
        XCTAssertEqual(createReminder?.name, "Create Reminder")
    }

    func testCommandsForApp() {
        let registry = AppRegistry.shared

        let messagesCmds = registry.commands(forApp: "Messages")
        XCTAssertFalse(messagesCmds.isEmpty)
        XCTAssertTrue(messagesCmds.contains { $0.id == "messages.send_message" })

        let unknownCmds = registry.commands(forApp: "NonexistentApp")
        XCTAssertTrue(unknownCmds.isEmpty)
    }

    func testSearchCommands() {
        let registry = AppRegistry.shared

        let sendResults = registry.searchCommands("send")
        XCTAssertFalse(sendResults.isEmpty)
        // Should find at least Messages send and Mail compose
        let cmdIds = sendResults.map { $0.command.id }
        XCTAssertTrue(cmdIds.contains("messages.send_message"))
    }

    // MARK: - Command Validation

    func testCommandValidationMissingRequired() {
        let cmd = AppCommand(
            id: "test.cmd",
            name: "Test",
            description: "A test command",
            parameters: [
                CommandParameter(name: "required_param", description: "Required", required: true),
                CommandParameter(name: "optional_param", description: "Optional", required: false),
            ]
        ) { _ in "" }

        let errors = cmd.validate(arguments: [:])
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("required_param"))
    }

    func testCommandValidationAllProvided() {
        let cmd = AppCommand(
            id: "test.cmd",
            name: "Test",
            description: "A test command",
            parameters: [
                CommandParameter(name: "name", description: "Name", required: true),
            ]
        ) { _ in "" }

        let errors = cmd.validate(arguments: ["name": "Alice"])
        XCTAssertTrue(errors.isEmpty)
    }

    func testCommandValidationAllowedValues() {
        let cmd = AppCommand(
            id: "test.cmd",
            name: "Test",
            description: "A test command",
            parameters: [
                CommandParameter(name: "color", description: "Color", allowedValues: ["red", "blue"]),
            ]
        ) { _ in "" }

        let validErrors = cmd.validate(arguments: ["color": "red"])
        XCTAssertTrue(validErrors.isEmpty)

        let invalidErrors = cmd.validate(arguments: ["color": "green"])
        XCTAssertEqual(invalidErrors.count, 1)
        XCTAssertTrue(invalidErrors[0].contains("green"))
    }

    func testCommandValidationDefaultValueNotRequired() {
        let cmd = AppCommand(
            id: "test.cmd",
            name: "Test",
            description: "A test command",
            parameters: [
                CommandParameter(name: "list", description: "List name", required: true, defaultValue: "Default"),
            ]
        ) { _ in "" }

        // Has a default value, so not providing it shouldn't error
        let errors = cmd.validate(arguments: [:])
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Script Generation

    func testCommandGeneratesScript() {
        let cmd = AppCommand(
            id: "test.greet",
            name: "Greet",
            description: "Greet someone",
            parameters: [
                CommandParameter(name: "name", description: "Person's name"),
            ]
        ) { args in
            let name = args["name", default: "World"]
            return "display dialog \"Hello, \(name)!\""
        }

        let script = cmd.generateScript(arguments: ["name": "Alice"])
        XCTAssertEqual(script, "display dialog \"Hello, Alice!\"")
    }

    // MARK: - App Protocol Conformance

    func testMessagesAppConformance() {
        XCTAssertEqual(MessagesApp.appName, "Messages")
        XCTAssertEqual(MessagesApp.category, .communication)
        XCTAssertFalse(MessagesApp.commands.isEmpty)
        XCTAssertTrue(MessagesApp.isBuiltIn)
    }

    func testRemindersAppConformance() {
        XCTAssertEqual(RemindersApp.appName, "Reminders")
        XCTAssertEqual(RemindersApp.category, .productivity)
        XCTAssertFalse(RemindersApp.commands.isEmpty)
    }

    func testAllAppsHaveUniqueCommandIDs() {
        let registry = AppRegistry.shared
        var seenIDs: Set<String> = []
        for appType in registry.allApps {
            for cmd in appType.commands {
                XCTAssertFalse(seenIDs.contains(cmd.id), "Duplicate command ID: \(cmd.id)")
                seenIDs.insert(cmd.id)
            }
        }
    }

    func testAllCommandsHaveDescriptions() {
        let registry = AppRegistry.shared
        for appType in registry.allApps {
            for cmd in appType.commands {
                XCTAssertFalse(cmd.description.isEmpty, "Command \(cmd.id) has empty description")
                XCTAssertFalse(cmd.name.isEmpty, "Command \(cmd.id) has empty name")
            }
        }
    }

    // MARK: - Manifest Generation

    func testGenerateManifest() {
        let registry = AppRegistry.shared
        let manifest = registry.generateManifest()

        XCTAssertFalse(manifest.isEmpty)

        // Verify structure of first entry
        if let firstApp = manifest.first {
            XCTAssertNotNil(firstApp["name"])
            XCTAssertNotNil(firstApp["bundleIdentifier"])
            XCTAssertNotNil(firstApp["commands"])
        }
    }

    // MARK: - Registration

    func testCustomAppRegistration() {
        let registry = AppRegistry()

        struct TestApp: ScriptableApp {
            static let bundleIdentifier = "com.test.app"
            static let appName = "TestApp"
            static let description = "A test app"
            static let category = AppCategory.other
            static let commands: [AppCommand] = []
        }

        registry.register(TestApp.self)
        XCTAssertNotNil(registry.app(named: "TestApp"))
        XCTAssertEqual(registry.allApps.count, 1)
    }

    // MARK: - AppCategory

    func testAppCategoryCaseIterable() {
        XCTAssertTrue(AppCategory.allCases.count > 0)
        XCTAssertTrue(AppCategory.allCases.contains(.communication))
        XCTAssertTrue(AppCategory.allCases.contains(.productivity))
    }

    // MARK: - ParameterType

    func testParameterTypeRawValues() {
        XCTAssertEqual(ParameterType.string.rawValue, "string")
        XCTAssertEqual(ParameterType.integer.rawValue, "integer")
        XCTAssertEqual(ParameterType.boolean.rawValue, "boolean")
        XCTAssertEqual(ParameterType.filePath.rawValue, "filePath")
        XCTAssertEqual(ParameterType.date.rawValue, "date")
        XCTAssertEqual(ParameterType.array.rawValue, "array")
    }
}
