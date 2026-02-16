import Foundation

/// Shortcut sheet for the macOS Terminal application.
///
/// Provides AppleScript commands for running shell commands, managing
/// Terminal windows and tabs, and configuring profiles.
public struct TerminalApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.Terminal"
    public static let appName = "Terminal"
    public static let description = "macOS command-line terminal emulator"
    public static let category = AppCategory.development

    public static let commands: [AppCommand] = [
        // --- Execution ---
        AppCommand(
            id: "terminal.run_command",
            name: "Run Command",
            description: "Execute a shell command in the frontmost Terminal window",
            category: "Execution",
            parameters: [
                CommandParameter(name: "command", description: "The shell command to execute"),
            ]
        ) { args in
            let command = args["command", default: ""]
            return """
            tell application "Terminal"
                if (count of windows) = 0 then
                    do script "\(command)"
                else
                    do script "\(command)" in front window
                end if
                activate
            end tell
            """
        },

        AppCommand(
            id: "terminal.run_command_new_window",
            name: "Run Command in New Window",
            description: "Execute a shell command in a new Terminal window",
            category: "Execution",
            parameters: [
                CommandParameter(name: "command", description: "The shell command to execute"),
            ]
        ) { args in
            let command = args["command", default: ""]
            return """
            tell application "Terminal"
                do script "\(command)"
                activate
            end tell
            """
        },

        AppCommand(
            id: "terminal.run_command_new_tab",
            name: "Run Command in New Tab",
            description: "Execute a shell command in a new tab of the front window",
            category: "Execution",
            parameters: [
                CommandParameter(name: "command", description: "The shell command to execute"),
            ]
        ) { args in
            let command = args["command", default: ""]
            return """
            tell application "Terminal"
                activate
                tell application "System Events"
                    keystroke "t" using command down
                end tell
                delay 0.5
                do script "\(command)" in front window
            end tell
            """
        },

        // --- Window Management ---
        AppCommand(
            id: "terminal.list_windows",
            name: "List Windows",
            description: "List all open Terminal windows and their tabs",
            category: "Windows",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                set winList to {}
                repeat with w in windows
                    set tabList to {}
                    repeat with t in tabs of w
                        set end of tabList to (history of t)
                    end repeat
                    set end of winList to ("Window " & (id of w as text) & ": " & (count of tabs of w) & " tabs")
                end repeat
                return winList
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_front_window_content",
            name: "Get Front Window Content",
            description: "Get the visible content of the frontmost Terminal window",
            category: "Windows",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return contents of selected tab of front window
            end tell
            """
        },

        // --- Profiles ---
        AppCommand(
            id: "terminal.set_profile",
            name: "Set Profile",
            description: "Change the profile (color scheme) of the current window",
            category: "Profiles",
            parameters: [
                CommandParameter(name: "profile", description: "The name of the Terminal profile (e.g. 'Pro', 'Basic', 'Ocean')"),
            ]
        ) { args in
            let profile = args["profile", default: "Basic"]
            return """
            tell application "Terminal"
                set current settings of selected tab of front window to settings set "\(profile)"
                return "Profile set to: \(profile)"
            end tell
            """
        },

        AppCommand(
            id: "terminal.list_profiles",
            name: "List Profiles",
            description: "List all available Terminal profiles",
            category: "Profiles",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return name of every settings set
            end tell
            """
        },

        // --- State ---
        AppCommand(
            id: "terminal.is_busy",
            name: "Is Busy",
            description: "Check if the frontmost Terminal tab is currently running a command",
            category: "State",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return busy of selected tab of front window
            end tell
            """
        },
    ]
}
