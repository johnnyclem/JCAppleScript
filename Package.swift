// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JCAppleScript",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "JCAppleScript",
            targets: ["JCAppleScript"]
        ),
        .library(
            name: "AppShortcuts",
            targets: ["AppShortcuts"]
        ),
        .executable(
            name: "jcas-mcp",
            targets: ["JCAppleScriptMCP"]
        ),
    ],
    targets: [
        // Core AppleScript execution engine
        .target(
            name: "JCAppleScript",
            path: "Sources/JCAppleScript"
        ),
        // App shortcut sheets and registry
        .target(
            name: "AppShortcuts",
            dependencies: ["JCAppleScript"],
            path: "Sources/AppShortcuts"
        ),
        // MCP server executable
        .executableTarget(
            name: "JCAppleScriptMCP",
            dependencies: ["JCAppleScript", "AppShortcuts"],
            path: "Sources/JCAppleScriptMCP"
        ),
        // Tests
        .testTarget(
            name: "JCAppleScriptTests",
            dependencies: ["JCAppleScript"],
            path: "Tests/JCAppleScriptTests"
        ),
        .testTarget(
            name: "AppShortcutsTests",
            dependencies: ["AppShortcuts"],
            path: "Tests/AppShortcutsTests"
        ),
    ]
)
