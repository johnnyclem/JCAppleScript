import XCTest
@testable import AppShortcuts

final class ManifestTests: XCTestCase {

    let sampleManifestJSON = """
    [
      {
        "name": "CoolApp",
        "bundleIdentifier": "com.example.coolapp",
        "description": "A community-contributed app",
        "category": "Productivity",
        "commands": [
          {
            "id": "coolapp.greet",
            "name": "Greet",
            "description": "Show a greeting",
            "category": "Fun",
            "script": "tell application \\"CoolApp\\"\\n    greet \\"${who}\\" times ${count}\\nend tell",
            "parameters": [
              {"name": "who", "description": "Who to greet", "required": true, "type": "string"},
              {"name": "count", "description": "Repeat count", "required": false, "type": "integer", "defaultValue": "1"}
            ]
          }
        ]
      }
    ]
    """

    func testDecodeManifestFromArray() throws {
        let manifest = try AppManifest.decode(from: Data(sampleManifestJSON.utf8))
        XCTAssertEqual(manifest.apps.count, 1)
        XCTAssertEqual(manifest.apps[0].name, "CoolApp")
        XCTAssertEqual(manifest.apps[0].commands.count, 1)
    }

    func testLoadManifestRegistersApp() throws {
        let registry = AppRegistry()
        let loaded = try registry.loadManifest(from: Data(sampleManifestJSON.utf8))
        XCTAssertEqual(loaded.count, 1)
        XCTAssertNotNil(registry.app(named: "coolapp"))
        XCTAssertNotNil(registry.command(withID: "coolapp.greet"))
    }

    func testTemplateCommandGeneratesSanitizedScript() throws {
        let registry = AppRegistry()
        try registry.loadManifest(from: Data(sampleManifestJSON.utf8))
        let cmd = try XCTUnwrap(registry.command(withID: "coolapp.greet"))

        let script = cmd.generateScript(arguments: ["who": "Wo\"rld", "count": "3"])
        XCTAssertTrue(script.contains("greet \"Wo\\\"rld\" times 3"), "Unexpected script:\n\(script)")

        // Default value applies when the optional arg is missing.
        let defaulted = cmd.generateScript(arguments: ["who": "hi"])
        XCTAssertTrue(defaulted.contains("times 1"))

        // Integer placeholder cannot carry injected code.
        let injected = cmd.generateScript(arguments: ["who": "x", "count": "1\nquit"])
        XCTAssertFalse(injected.contains("quit"))
    }

    func testManifestRejectsUnknownCategory() {
        let json = """
        [{"name": "X", "bundleIdentifier": "x", "description": "x", "category": "Bogus", "commands": []}]
        """
        XCTAssertThrowsError(try AppManifest.decode(from: Data(json.utf8)).definitions())
    }

    func testManifestRejectsCommandWithoutScript() {
        let json = """
        [{"name": "X", "bundleIdentifier": "x", "description": "x", "category": "Other",
          "commands": [{"id": "x.y", "name": "Y", "description": "y", "parameters": []}]}]
        """
        XCTAssertThrowsError(try AppManifest.decode(from: Data(json.utf8)).definitions())
    }

    func testExportRoundTrip() throws {
        let registry = AppRegistry()
        try registry.loadManifest(from: Data(sampleManifestJSON.utf8))

        let exported = try registry.exportManifestJSON()
        let reimported = try AppManifest.decode(from: exported)
        XCTAssertEqual(reimported.apps.count, 1)
        XCTAssertEqual(reimported.apps[0].commands[0].script?.isEmpty, false)

        // A second registry can be built from the export.
        let second = AppRegistry()
        try second.loadManifest(from: exported)
        XCTAssertNotNil(second.command(withID: "coolapp.greet"))
    }

    func testBuiltInRegistryExportsManifest() throws {
        let data = try AppRegistry.shared.exportManifestJSON()
        let manifest = try AppManifest.decode(from: data)
        XCTAssertTrue(manifest.apps.contains { $0.name == "Messages" })
        // Built-in commands are closure-based, so they export without script
        // templates - the manifest still documents their parameters.
        let messages = try XCTUnwrap(manifest.apps.first { $0.name == "Messages" })
        XCTAssertFalse(messages.commands.isEmpty)
    }

    func testUnregister() throws {
        let registry = AppRegistry()
        try registry.loadManifest(from: Data(sampleManifestJSON.utf8))
        XCTAssertNotNil(registry.unregister(named: "CoolApp"))
        XCTAssertNil(registry.app(named: "CoolApp"))
        XCTAssertNil(registry.unregister(named: "CoolApp"))
    }
}
