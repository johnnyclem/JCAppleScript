import Foundation

/// Shortcut sheet for the macOS Safari application.
///
/// Provides AppleScript commands for tab management, navigation,
/// reading page content, and browser automation.
public struct SafariApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.Safari"
    public static let appName = "Safari"
    public static let description = "Apple's web browser - browse the web, manage tabs, and automate web tasks"
    public static let category = AppCategory.internet

    public static let commands: [AppCommand] = [
        // --- Navigation ---
        AppCommand(
            id: "safari.open_url",
            name: "Open URL",
            description: "Open a URL in Safari, optionally in a new tab or window",
            category: "Navigation",
            parameters: [
                CommandParameter(name: "url", description: "The URL to open"),
                CommandParameter(name: "newWindow", description: "Open in a new window instead of the current tab", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let url = args["url", default: ""]
            let newWindow = args["newWindow", default: "false"] == "true"
            if newWindow {
                return """
                tell application "Safari"
                    make new document with properties {URL:"\(url)"}
                    activate
                end tell
                """
            } else {
                return """
                tell application "Safari"
                    if (count of windows) = 0 then
                        make new document with properties {URL:"\(url)"}
                    else
                        set URL of front document to "\(url)"
                    end if
                    activate
                end tell
                """
            }
        },

        AppCommand(
            id: "safari.new_tab",
            name: "New Tab",
            description: "Open a new tab with an optional URL",
            category: "Navigation",
            parameters: [
                CommandParameter(name: "url", description: "The URL to open in the new tab", required: false, defaultValue: ""),
            ]
        ) { args in
            let url = args["url", default: ""]
            if url.isEmpty {
                return """
                tell application "Safari"
                    tell front window
                        set newTab to make new tab
                    end tell
                    activate
                end tell
                """
            } else {
                return """
                tell application "Safari"
                    tell front window
                        set newTab to make new tab with properties {URL:"\(url)"}
                    end tell
                    activate
                end tell
                """
            }
        },

        // --- Tab Management ---
        AppCommand(
            id: "safari.list_tabs",
            name: "List Tabs",
            description: "Get a list of all open tabs with their titles and URLs",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                set tabList to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        set end of tabList to (name of t & " | " & URL of t)
                    end repeat
                end repeat
                return tabList
            end tell
            """
        },

        AppCommand(
            id: "safari.close_tab",
            name: "Close Tab",
            description: "Close the current tab",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                tell front window
                    close current tab
                end tell
            end tell
            """
        },

        AppCommand(
            id: "safari.switch_tab",
            name: "Switch Tab",
            description: "Switch to a specific tab by index (1-based)",
            category: "Tabs",
            parameters: [
                CommandParameter(name: "index", description: "Tab index (1-based)", type: .integer),
            ]
        ) { args in
            let index = args["index", default: "1"]
            return """
            tell application "Safari"
                tell front window
                    set current tab to tab \(index)
                end tell
                activate
            end tell
            """
        },

        // --- Reading Page Content ---
        AppCommand(
            id: "safari.get_current_url",
            name: "Get Current URL",
            description: "Get the URL of the current page",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                return URL of front document
            end tell
            """
        },

        AppCommand(
            id: "safari.get_page_title",
            name: "Get Page Title",
            description: "Get the title of the current page",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                return name of front document
            end tell
            """
        },

        AppCommand(
            id: "safari.get_page_source",
            name: "Get Page Source",
            description: "Get the HTML source of the current page",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                return source of front document
            end tell
            """
        },

        AppCommand(
            id: "safari.get_page_text",
            name: "Get Page Text",
            description: "Get the visible text content of the current page",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                return text of front document
            end tell
            """
        },

        // --- JavaScript ---
        AppCommand(
            id: "safari.run_javascript",
            name: "Run JavaScript",
            description: "Execute JavaScript in the current tab and return the result",
            category: "JavaScript",
            parameters: [
                CommandParameter(name: "script", description: "The JavaScript code to execute"),
            ],
            dangerous: true
        ) { args in
            let script = args["script", default: ""]
            return """
            tell application "Safari"
                return do JavaScript "\(script)" in front document
            end tell
            """
        },

        // --- Bookmarks ---
        AppCommand(
            id: "safari.add_bookmark",
            name: "Add Reading List Item",
            description: "Add the current page to the Reading List",
            category: "Bookmarks",
            parameters: []
        ) { _ in
            """
            tell application "Safari"
                add reading list item (URL of front document)
            end tell
            """
        },
    ]
}
