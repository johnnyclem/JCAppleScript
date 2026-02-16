import Foundation

/// Shortcut sheet for the macOS Finder application.
///
/// Provides AppleScript commands for file management, window control,
/// and desktop operations.
public struct FinderApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.finder"
    public static let appName = "Finder"
    public static let description = "File manager for macOS - browse, organize, and manage files and folders"
    public static let category = AppCategory.system

    public static let commands: [AppCommand] = [
        // --- File Operations ---
        AppCommand(
            id: "finder.get_selection",
            name: "Get Selection",
            description: "Get the currently selected files and folders in Finder",
            category: "File Operations",
            parameters: []
        ) { _ in
            """
            tell application "Finder"
                set selectedItems to selection
                set pathList to {}
                repeat with anItem in selectedItems
                    set end of pathList to (POSIX path of (anItem as alias))
                end repeat
                return pathList
            end tell
            """
        },

        AppCommand(
            id: "finder.reveal_file",
            name: "Reveal File",
            description: "Reveal a file or folder in Finder",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the file or folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                reveal POSIX file "\(path)"
                activate
            end tell
            """
        },

        AppCommand(
            id: "finder.move_to_trash",
            name: "Move to Trash",
            description: "Move a file or folder to the Trash",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the file or folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                move POSIX file "\(path)" to trash
                return "Moved to trash: \(path)"
            end tell
            """
        },

        AppCommand(
            id: "finder.duplicate_file",
            name: "Duplicate File",
            description: "Create a copy of a file or folder",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the file or folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                set theFile to POSIX file "\(path)" as alias
                set theCopy to duplicate theFile
                return POSIX path of (theCopy as alias)
            end tell
            """
        },

        AppCommand(
            id: "finder.create_folder",
            name: "Create Folder",
            description: "Create a new folder at the specified path",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "parentPath", description: "POSIX path to the parent directory", type: .filePath),
                CommandParameter(name: "name", description: "Name of the new folder"),
            ]
        ) { args in
            let parentPath = args["parentPath", default: ""]
            let name = args["name", default: "New Folder"]
            return """
            tell application "Finder"
                set parentFolder to POSIX file "\(parentPath)" as alias
                make new folder at parentFolder with properties {name:"\(name)"}
                return "Created folder: \(name)"
            end tell
            """
        },

        AppCommand(
            id: "finder.list_folder_contents",
            name: "List Folder Contents",
            description: "List files and folders in a directory",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                set theFolder to POSIX file "\(path)" as alias
                set itemList to {}
                repeat with anItem in (every item of theFolder)
                    set itemInfo to name of anItem
                    if class of anItem is folder then
                        set itemInfo to "[DIR] " & itemInfo
                    end if
                    set end of itemList to itemInfo
                end repeat
                return itemList
            end tell
            """
        },

        AppCommand(
            id: "finder.get_file_info",
            name: "Get File Info",
            description: "Get detailed information about a file or folder",
            category: "File Operations",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the file or folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                set theFile to POSIX file "\(path)" as alias
                set theItem to item theFile
                set itemName to name of theItem
                set itemSize to size of theItem
                set itemKind to kind of theItem
                set itemCreated to creation date of theItem
                set itemModified to modification date of theItem
                return "Name: " & itemName & return & "Size: " & (itemSize as text) & " bytes" & return & "Kind: " & itemKind & return & "Created: " & (itemCreated as text) & return & "Modified: " & (itemModified as text)
            end tell
            """
        },

        // --- Window Management ---
        AppCommand(
            id: "finder.get_front_window_path",
            name: "Get Front Window Path",
            description: "Get the POSIX path of the frontmost Finder window's location",
            category: "Windows",
            parameters: []
        ) { _ in
            """
            tell application "Finder"
                if (count of windows) > 0 then
                    return POSIX path of (target of front window as alias)
                else
                    return "No Finder windows open"
                end if
            end tell
            """
        },

        AppCommand(
            id: "finder.open_folder",
            name: "Open Folder",
            description: "Open a folder in a new Finder window",
            category: "Windows",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the folder", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Finder"
                open POSIX file "\(path)"
                activate
            end tell
            """
        },

        // --- Desktop ---
        AppCommand(
            id: "finder.empty_trash",
            name: "Empty Trash",
            description: "Empty the Trash (with optional security warning)",
            category: "Desktop",
            parameters: []
        ) { _ in
            """
            tell application "Finder"
                empty trash
                return "Trash emptied"
            end tell
            """
        },

        AppCommand(
            id: "finder.get_desktop_items",
            name: "Get Desktop Items",
            description: "List all items on the Desktop",
            category: "Desktop",
            parameters: []
        ) { _ in
            """
            tell application "Finder"
                set desktopItems to {}
                repeat with anItem in (every item of desktop)
                    set end of desktopItems to name of anItem
                end repeat
                return desktopItems
            end tell
            """
        },

        // --- Labels/Tags ---
        AppCommand(
            id: "finder.set_label",
            name: "Set Label",
            description: "Set the color label of a file or folder",
            category: "Labels",
            parameters: [
                CommandParameter(name: "path", description: "POSIX path to the file or folder", type: .filePath),
                CommandParameter(name: "labelIndex", description: "Label color index (0=none, 1=orange, 2=red, 3=yellow, 4=blue, 5=purple, 6=green, 7=gray)", type: .integer, allowedValues: ["0", "1", "2", "3", "4", "5", "6", "7"]),
            ]
        ) { args in
            let path = args["path", default: ""]
            let label = args["labelIndex", default: "0"]
            return """
            tell application "Finder"
                set theItem to POSIX file "\(path)" as alias
                set label index of item theItem to \(label)
                return "Label set to \(label) for \(path)"
            end tell
            """
        },
    ]
}
