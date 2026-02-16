import Foundation

/// Shortcut sheet for the macOS Notes application.
///
/// Provides AppleScript commands for creating, reading, searching,
/// and managing notes and folders.
public struct NotesApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.Notes"
    public static let appName = "Notes"
    public static let description = "Create and organize notes with rich text, checklists, and attachments"
    public static let category = AppCategory.productivity

    public static let commands: [AppCommand] = [
        // --- Creating ---
        AppCommand(
            id: "notes.create_note",
            name: "Create Note",
            description: "Create a new note in a specified folder",
            category: "Creating",
            parameters: [
                CommandParameter(name: "title", description: "The title (name) of the note"),
                CommandParameter(name: "body", description: "The body text of the note"),
                CommandParameter(name: "folder", description: "The folder to create the note in", required: false, defaultValue: "Notes"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let body = args["body", default: ""]
            let folder = args["folder", default: "Notes"]
            return """
            tell application "Notes"
                tell folder "\(folder)"
                    make new note with properties {name:"\(title)", body:"\(body)"}
                end tell
                return "Created note: \(title)"
            end tell
            """
        },

        AppCommand(
            id: "notes.create_folder",
            name: "Create Folder",
            description: "Create a new folder for organizing notes",
            category: "Creating",
            parameters: [
                CommandParameter(name: "name", description: "The name of the new folder"),
            ]
        ) { args in
            let name = args["name", default: ""]
            return """
            tell application "Notes"
                make new folder with properties {name:"\(name)"}
                return "Created folder: \(name)"
            end tell
            """
        },

        // --- Reading ---
        AppCommand(
            id: "notes.list_folders",
            name: "List Folders",
            description: "Get the names of all note folders",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Notes"
                return name of every folder
            end tell
            """
        },

        AppCommand(
            id: "notes.list_notes",
            name: "List Notes",
            description: "List all notes in a folder",
            category: "Reading",
            parameters: [
                CommandParameter(name: "folder", description: "The folder name", required: false, defaultValue: "Notes"),
            ]
        ) { args in
            let folder = args["folder", default: "Notes"]
            return """
            tell application "Notes"
                set noteList to {}
                tell folder "\(folder)"
                    repeat with n in notes
                        set noteInfo to name of n & " (modified: " & (modification date of n as text) & ")"
                        set end of noteList to noteInfo
                    end repeat
                end tell
                return noteList
            end tell
            """
        },

        AppCommand(
            id: "notes.get_note_content",
            name: "Get Note Content",
            description: "Get the full content of a note by its title",
            category: "Reading",
            parameters: [
                CommandParameter(name: "title", description: "The title of the note"),
                CommandParameter(name: "folder", description: "The folder to search in", required: false, defaultValue: "Notes"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let folder = args["folder", default: "Notes"]
            return """
            tell application "Notes"
                tell folder "\(folder)"
                    set targetNote to first note whose name is "\(title)"
                    return plaintext of targetNote
                end tell
            end tell
            """
        },

        AppCommand(
            id: "notes.search_notes",
            name: "Search Notes",
            description: "Search for notes containing a keyword",
            category: "Reading",
            parameters: [
                CommandParameter(name: "query", description: "Search keyword"),
            ]
        ) { args in
            let query = args["query", default: ""]
            return """
            tell application "Notes"
                set results to {}
                repeat with n in notes
                    if name of n contains "\(query)" or plaintext of n contains "\(query)" then
                        set end of results to (name of n & " (in: " & name of container of n & ")")
                    end if
                end repeat
                return results
            end tell
            """
        },

        // --- Updating ---
        AppCommand(
            id: "notes.append_to_note",
            name: "Append to Note",
            description: "Append text to an existing note",
            category: "Updating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the note to append to"),
                CommandParameter(name: "text", description: "The text to append"),
                CommandParameter(name: "folder", description: "The folder the note is in", required: false, defaultValue: "Notes"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let text = args["text", default: ""]
            let folder = args["folder", default: "Notes"]
            return """
            tell application "Notes"
                tell folder "\(folder)"
                    set targetNote to first note whose name is "\(title)"
                    set body of targetNote to (body of targetNote & "<br>" & "\(text)")
                end tell
                return "Appended to note: \(title)"
            end tell
            """
        },

        AppCommand(
            id: "notes.delete_note",
            name: "Delete Note",
            description: "Delete a note by its title",
            category: "Updating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the note to delete"),
                CommandParameter(name: "folder", description: "The folder the note is in", required: false, defaultValue: "Notes"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let folder = args["folder", default: "Notes"]
            return """
            tell application "Notes"
                tell folder "\(folder)"
                    delete (first note whose name is "\(title)")
                end tell
                return "Deleted note: \(title)"
            end tell
            """
        },

        // --- Counting ---
        AppCommand(
            id: "notes.count_notes",
            name: "Count Notes",
            description: "Count the number of notes in a folder or across all folders",
            category: "Reading",
            parameters: [
                CommandParameter(name: "folder", description: "Folder name (leave empty for total count)", required: false),
            ]
        ) { args in
            if let folder = args["folder"], !folder.isEmpty {
                return """
                tell application "Notes"
                    return count of notes of folder "\(folder)"
                end tell
                """
            } else {
                return """
                tell application "Notes"
                    return count of notes
                end tell
                """
            }
        },
    ]
}
