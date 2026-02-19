import Foundation

/// Shortcut sheet for the macOS Terminal application.
///
/// Provides AppleScript commands for running shell commands, managing
/// Terminal windows and tabs, and configuring profiles and settings.
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

        AppCommand(
            id: "terminal.run_command_in_tab",
            name: "Run Command in Tab",
            description: "Execute a shell command in a specific tab by index (1-based)",
            category: "Execution",
            parameters: [
                CommandParameter(name: "command", description: "The shell command to execute"),
                CommandParameter(name: "tabIndex", description: "The 1-based index of the tab", type: .integer),
            ]
        ) { args in
            let command = args["command", default: ""]
            let tabIndex = args["tabIndex", default: "1"]
            return """
            tell application "Terminal"
                do script "\(command)" in tab \(tabIndex) of front window
                activate
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
            description: "Get the visible content of the frontmost Terminal window's selected tab",
            category: "Windows",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return contents of selected tab of front window
            end tell
            """
        },

        AppCommand(
            id: "terminal.close_front_window",
            name: "Close Front Window",
            description: "Close the frontmost Terminal window",
            category: "Windows",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                close front window
            end tell
            """
        },

        // --- Tabs ---
        AppCommand(
            id: "terminal.get_tab_history",
            name: "Get Tab History",
            description: "Get the entire scrolling buffer contents of the selected tab",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return history of selected tab of front window
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_tab_processes",
            name: "Get Tab Processes",
            description: "Get the list of processes currently running in the selected tab",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return processes of selected tab of front window
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_tab_tty",
            name: "Get Tab TTY",
            description: "Get the TTY device path of the selected tab",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return tty of selected tab of front window
            end tell
            """
        },

        AppCommand(
            id: "terminal.select_tab",
            name: "Select Tab",
            description: "Select a specific tab by index (1-based) in the front window",
            category: "Tabs",
            parameters: [
                CommandParameter(name: "index", description: "Tab index (1-based)", type: .integer),
            ]
        ) { args in
            let index = args["index", default: "1"]
            return """
            tell application "Terminal"
                set selected of tab \(index) of front window to true
                activate
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_tab_info",
            name: "Get Tab Info",
            description: "Get detailed information about the selected tab including size, TTY, busy state, and processes",
            category: "Tabs",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                set t to selected tab of front window
                set tabRows to number of rows of t
                set tabCols to number of columns of t
                set tabTty to tty of t
                set tabBusy to busy of t
                set tabProcs to processes of t
                set tabTitle to custom title of t
                return "rows:" & tabRows & ", columns:" & tabCols & ", tty:" & tabTty & ", busy:" & tabBusy & ", custom title:" & tabTitle & ", processes:" & tabProcs
            end tell
            """
        },

        AppCommand(
            id: "terminal.set_tab_size",
            name: "Set Tab Size",
            description: "Set the number of rows and columns displayed in the selected tab",
            category: "Tabs",
            parameters: [
                CommandParameter(name: "rows", description: "Number of rows", required: false, type: .integer),
                CommandParameter(name: "columns", description: "Number of columns", required: false, type: .integer),
            ]
        ) { args in
            var lines: [String] = []
            lines.append("tell application \"Terminal\"")
            lines.append("    set t to selected tab of front window")
            if let rows = args["rows"], !rows.isEmpty {
                lines.append("    set number of rows of t to \(rows)")
            }
            if let columns = args["columns"], !columns.isEmpty {
                lines.append("    set number of columns of t to \(columns)")
            }
            lines.append("end tell")
            return lines.joined(separator: "\n")
        },

        AppCommand(
            id: "terminal.set_custom_title",
            name: "Set Custom Title",
            description: "Set a custom title on the selected tab",
            category: "Tabs",
            parameters: [
                CommandParameter(name: "title", description: "The custom title text"),
            ]
        ) { args in
            let title = args["title", default: ""]
            return """
            tell application "Terminal"
                set t to selected tab of front window
                set title displays custom title of t to true
                set custom title of t to "\(title)"
            end tell
            """
        },

        // --- Profiles ---
        AppCommand(
            id: "terminal.set_profile",
            name: "Set Profile",
            description: "Change the profile (settings set) of the current tab",
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
            description: "List all available Terminal profiles (settings sets)",
            category: "Profiles",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return name of every settings set
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_profile_details",
            name: "Get Profile Details",
            description: "Get the detailed settings of a named profile including font, colors, and size",
            category: "Profiles",
            parameters: [
                CommandParameter(name: "profile", description: "The name of the profile"),
            ]
        ) { args in
            let profile = args["profile", default: "Basic"]
            return """
            tell application "Terminal"
                set s to settings set "\(profile)"
                set fName to font name of s
                set fSize to font size of s
                set fAA to font antialiasing of s
                set nRows to number of rows of s
                set nCols to number of columns of s
                set bgColor to background color of s
                set txtColor to normal text color of s
                set bldColor to bold text color of s
                set curColor to cursor color of s
                set cTitle to custom title of s
                return "font:" & fName & " " & fSize & "pt, antialiasing:" & fAA & ", size:" & nRows & "x" & nCols & ", custom title:" & cTitle
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_default_profile",
            name: "Get Default Profile",
            description: "Get the name of the default settings set used for new windows",
            category: "Profiles",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return name of default settings
            end tell
            """
        },

        AppCommand(
            id: "terminal.set_default_profile",
            name: "Set Default Profile",
            description: "Set the default settings set used for new windows",
            category: "Profiles",
            parameters: [
                CommandParameter(name: "profile", description: "The name of the profile to set as default"),
            ]
        ) { args in
            let profile = args["profile", default: "Basic"]
            return """
            tell application "Terminal"
                set default settings to settings set "\(profile)"
                return "Default profile set to: \(profile)"
            end tell
            """
        },

        AppCommand(
            id: "terminal.get_startup_profile",
            name: "Get Startup Profile",
            description: "Get the name of the settings set used for the window created on application startup",
            category: "Profiles",
            parameters: []
        ) { _ in
            """
            tell application "Terminal"
                return name of startup settings
            end tell
            """
        },

        AppCommand(
            id: "terminal.set_startup_profile",
            name: "Set Startup Profile",
            description: "Set the settings set used for the window created on application startup",
            category: "Profiles",
            parameters: [
                CommandParameter(name: "profile", description: "The name of the profile to set as startup"),
            ]
        ) { args in
            let profile = args["profile", default: "Basic"]
            return """
            tell application "Terminal"
                set startup settings to settings set "\(profile)"
                return "Startup profile set to: \(profile)"
            end tell
            """
        },

        // --- Appearance ---
        AppCommand(
            id: "terminal.set_font",
            name: "Set Font",
            description: "Set the font name and size for the current tab's settings",
            category: "Appearance",
            parameters: [
                CommandParameter(name: "fontName", description: "The font name (e.g. 'Menlo', 'SF Mono')", required: false),
                CommandParameter(name: "fontSize", description: "The font size in points", required: false, type: .integer),
                CommandParameter(name: "antialiasing", description: "Whether to enable font antialiasing", required: false, type: .boolean),
            ]
        ) { args in
            var lines: [String] = []
            lines.append("tell application \"Terminal\"")
            lines.append("    set s to current settings of selected tab of front window")
            if let fontName = args["fontName"], !fontName.isEmpty {
                lines.append("    set font name of s to \"\(fontName)\"")
            }
            if let fontSize = args["fontSize"], !fontSize.isEmpty {
                lines.append("    set font size of s to \(fontSize)")
            }
            if let aa = args["antialiasing"], !aa.isEmpty {
                lines.append("    set font antialiasing of s to \(aa)")
            }
            lines.append("end tell")
            return lines.joined(separator: "\n")
        },

        AppCommand(
            id: "terminal.set_colors",
            name: "Set Colors",
            description: "Set colors for the current tab's settings. Colors are specified as {red, green, blue} values from 0-65535",
            category: "Appearance",
            parameters: [
                CommandParameter(name: "backgroundColor", description: "Background color as comma-separated RGB (e.g. '0,0,0' for black)", required: false),
                CommandParameter(name: "normalTextColor", description: "Normal text color as comma-separated RGB (e.g. '65535,65535,65535' for white)", required: false),
                CommandParameter(name: "boldTextColor", description: "Bold text color as comma-separated RGB", required: false),
                CommandParameter(name: "cursorColor", description: "Cursor color as comma-separated RGB", required: false),
            ]
        ) { args in
            var lines: [String] = []
            lines.append("tell application \"Terminal\"")
            lines.append("    set s to current settings of selected tab of front window")
            if let bg = args["backgroundColor"], !bg.isEmpty {
                lines.append("    set background color of s to {\(bg)}")
            }
            if let txt = args["normalTextColor"], !txt.isEmpty {
                lines.append("    set normal text color of s to {\(txt)}")
            }
            if let bld = args["boldTextColor"], !bld.isEmpty {
                lines.append("    set bold text color of s to {\(bld)}")
            }
            if let cur = args["cursorColor"], !cur.isEmpty {
                lines.append("    set cursor color of s to {\(cur)}")
            }
            lines.append("end tell")
            return lines.joined(separator: "\n")
        },

        AppCommand(
            id: "terminal.configure_title",
            name: "Configure Title",
            description: "Configure what the tab title bar displays",
            category: "Appearance",
            parameters: [
                CommandParameter(name: "showDeviceName", description: "Show the device name in the title", required: false, type: .boolean),
                CommandParameter(name: "showShellPath", description: "Show the shell path in the title", required: false, type: .boolean),
                CommandParameter(name: "showWindowSize", description: "Show the window size in the title", required: false, type: .boolean),
                CommandParameter(name: "showSettingsName", description: "Show the settings name in the title", required: false, type: .boolean),
                CommandParameter(name: "showCustomTitle", description: "Show a custom title", required: false, type: .boolean),
            ]
        ) { args in
            var lines: [String] = []
            lines.append("tell application \"Terminal\"")
            lines.append("    set s to current settings of selected tab of front window")
            if let v = args["showDeviceName"], !v.isEmpty {
                lines.append("    set title displays device name of s to \(v)")
            }
            if let v = args["showShellPath"], !v.isEmpty {
                lines.append("    set title displays shell path of s to \(v)")
            }
            if let v = args["showWindowSize"], !v.isEmpty {
                lines.append("    set title displays window size of s to \(v)")
            }
            if let v = args["showSettingsName"], !v.isEmpty {
                lines.append("    set title displays settings name of s to \(v)")
            }
            if let v = args["showCustomTitle"], !v.isEmpty {
                lines.append("    set title displays custom title of s to \(v)")
            }
            lines.append("end tell")
            return lines.joined(separator: "\n")
        },

        AppCommand(
            id: "terminal.set_clean_commands",
            name: "Set Clean Commands",
            description: "Set the list of processes that will be ignored when checking whether a tab can be closed without a prompt",
            category: "Appearance",
            parameters: [
                CommandParameter(name: "commands", description: "Comma-separated list of process names (e.g. 'screen,tmux,login')"),
            ]
        ) { args in
            let commands = args["commands", default: ""]
            let items = commands.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
            let listStr = items.joined(separator: ", ")
            return """
            tell application "Terminal"
                set clean commands of current settings of selected tab of front window to {\(listStr)}
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
