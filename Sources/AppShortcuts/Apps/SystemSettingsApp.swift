import Foundation

/// Shortcut sheet for macOS System Settings (formerly System Preferences).
///
/// Provides AppleScript commands for opening specific preference panes,
/// querying system information, and controlling system behaviors.
public struct SystemSettingsApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.systempreferences"
    public static let appName = "System Settings"
    public static let description = "macOS system configuration and preferences"
    public static let category = AppCategory.system

    public static let commands: [AppCommand] = [
        // --- Navigation ---
        AppCommand(
            id: "system_settings.open_pane",
            name: "Open Settings Pane",
            description: "Open a specific System Settings pane by its anchor ID",
            category: "Navigation",
            parameters: [
                CommandParameter(name: "pane", description: "The pane identifier (e.g. 'com.apple.preferences.wifi', 'com.apple.Sound-Settings.extension')"),
            ]
        ) { args in
            let pane = args["pane", default: ""]
            return """
            tell application "System Settings"
                activate
                reveal anchor "\(pane)"
            end tell
            """
        },

        // --- System Info (via System Events) ---
        AppCommand(
            id: "system_settings.get_computer_name",
            name: "Get Computer Name",
            description: "Get the name of this Mac",
            category: "System Info",
            parameters: []
        ) { _ in
            """
            return computer name of (system info)
            """
        },

        AppCommand(
            id: "system_settings.get_system_version",
            name: "Get System Version",
            description: "Get the macOS version",
            category: "System Info",
            parameters: []
        ) { _ in
            """
            return system version of (system info)
            """
        },

        AppCommand(
            id: "system_settings.get_user_name",
            name: "Get User Name",
            description: "Get the current user's short name",
            category: "System Info",
            parameters: []
        ) { _ in
            """
            return short user name of (system info)
            """
        },

        // --- Appearance (via System Events) ---
        AppCommand(
            id: "system_settings.get_dark_mode",
            name: "Get Dark Mode",
            description: "Check whether dark mode is enabled",
            category: "Appearance",
            parameters: []
        ) { _ in
            """
            tell application "System Events"
                tell appearance preferences
                    return dark mode
                end tell
            end tell
            """
        },

        AppCommand(
            id: "system_settings.set_dark_mode",
            name: "Set Dark Mode",
            description: "Enable or disable dark mode",
            category: "Appearance",
            parameters: [
                CommandParameter(name: "enabled", description: "Whether to enable dark mode", type: .boolean),
            ]
        ) { args in
            let enabled = args["enabled", default: "true"]
            return """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to \(enabled)
                end tell
            end tell
            return "Dark mode: \(enabled)"
            """
        },

        // --- Volume Control (via osascript built-ins) ---
        AppCommand(
            id: "system_settings.get_volume",
            name: "Get Volume",
            description: "Get the current system audio output volume",
            category: "Audio",
            parameters: []
        ) { _ in
            """
            output volume of (get volume settings)
            """
        },

        AppCommand(
            id: "system_settings.set_volume",
            name: "Set Volume",
            description: "Set the system audio output volume (0-100)",
            category: "Audio",
            parameters: [
                CommandParameter(name: "volume", description: "Volume level from 0 to 100", type: .integer),
            ]
        ) { args in
            let volume = args["volume", default: "50"]
            return """
            set volume output volume \(volume)
            return "Volume set to \(volume)"
            """
        },

        AppCommand(
            id: "system_settings.toggle_mute",
            name: "Toggle Mute",
            description: "Mute or unmute the system audio",
            category: "Audio",
            parameters: [
                CommandParameter(name: "mute", description: "Whether to mute", type: .boolean),
            ]
        ) { args in
            let mute = args["mute", default: "true"]
            return """
            set volume output muted \(mute)
            return "Muted: \(mute)"
            """
        },

        // --- Display ---
        AppCommand(
            id: "system_settings.get_screen_resolution",
            name: "Get Screen Resolution",
            description: "Get the current screen resolution of the main display",
            category: "Display",
            parameters: []
        ) { _ in
            """
            tell application "Finder"
                set screenBounds to bounds of window of desktop
                set screenWidth to item 3 of screenBounds
                set screenHeight to item 4 of screenBounds
                return (screenWidth as text) & "x" & (screenHeight as text)
            end tell
            """
        },

        // --- Power ---
        AppCommand(
            id: "system_settings.sleep",
            name: "Sleep",
            description: "Put the Mac to sleep",
            category: "Power",
            parameters: []
        ) { _ in
            """
            tell application "System Events"
                sleep
            end tell
            """
        },

        AppCommand(
            id: "system_settings.screensaver",
            name: "Start Screen Saver",
            description: "Start the screen saver",
            category: "Power",
            parameters: []
        ) { _ in
            """
            tell application "System Events"
                start current screen saver
            end tell
            """
        },

        // --- Notifications ---
        AppCommand(
            id: "system_settings.show_notification",
            name: "Show Notification",
            description: "Display a macOS notification banner",
            category: "Notifications",
            parameters: [
                CommandParameter(name: "title", description: "The notification title"),
                CommandParameter(name: "message", description: "The notification message"),
                CommandParameter(name: "subtitle", description: "Optional subtitle", required: false),
                CommandParameter(name: "sound", description: "Optional sound name (e.g. 'Glass', 'Basso')", required: false),
            ]
        ) { args in
            let title = args["title", default: ""]
            let message = args["message", default: ""]
            let subtitle = args["subtitle"]
            let sound = args["sound"]
            var props = "\"" + message + "\" with title \"" + title + "\""
            if let subtitle = subtitle { props += " subtitle \"\(subtitle)\"" }
            if let sound = sound { props += " sound name \"\(sound)\"" }
            return "display notification \(props)"
        },

        // --- Dialog ---
        AppCommand(
            id: "system_settings.show_dialog",
            name: "Show Dialog",
            description: "Display a dialog box with a message and buttons",
            category: "Notifications",
            parameters: [
                CommandParameter(name: "message", description: "The dialog message"),
                CommandParameter(name: "title", description: "The dialog title", required: false, defaultValue: ""),
                CommandParameter(name: "buttons", description: "Comma-separated list of button labels", required: false, defaultValue: "OK"),
            ]
        ) { args in
            let message = args["message", default: ""]
            let title = args["title", default: ""]
            let buttons = args["buttons", default: "OK"]
            let buttonList = buttons.components(separatedBy: ",")
                .map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                .joined(separator: ", ")
            var script = "display dialog \"\(message)\" buttons {\(buttonList)}"
            if !title.isEmpty { script += " with title \"\(title)\"" }
            script += "\nreturn button returned of result"
            return script
        },
    ]
}
