import Foundation

/// Shortcut sheet for the macOS Reminders application.
///
/// Provides AppleScript commands for creating, listing, completing,
/// and managing reminders and reminder lists.
public struct RemindersApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.reminders"
    public static let appName = "Reminders"
    public static let description = "Create and manage reminders, to-do lists, and tasks"
    public static let category = AppCategory.productivity

    public static let commands: [AppCommand] = [
        // --- Creating ---
        AppCommand(
            id: "reminders.create_reminder",
            name: "Create Reminder",
            description: "Create a new reminder in a specified list",
            category: "Creating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the reminder"),
                CommandParameter(name: "list", description: "The name of the reminder list", required: false, defaultValue: "Reminders"),
                CommandParameter(name: "notes", description: "Additional notes for the reminder", required: false),
                CommandParameter(name: "dueDate", description: "Due date in format 'YYYY-MM-DD HH:MM'", required: false, type: .date),
                CommandParameter(name: "priority", description: "Priority level", required: false, type: .integer, allowedValues: ["0", "1", "5", "9"]),
            ]
        ) { args in
            let title = args["title", default: ""]
            let list = args["list", default: "Reminders"]
            let notes = args["notes"]
            let dueDate = args["dueDate"]
            let priority = args["priority"]

            var props = "name:\"\(title)\""
            if let notes = notes { props += ", body:\"\(notes)\"" }
            if let priority = priority { props += ", priority:\(priority)" }

            var script = """
            tell application "Reminders"
                set targetList to list "\(list)"
                set newReminder to make new reminder at end of reminders of targetList with properties {\(props)}
            """
            if let dueDate = dueDate {
                script += """

                    set due date of newReminder to date "\(dueDate)"
                """
            }
            script += """

                return name of newReminder
            end tell
            """
            return script
        },

        AppCommand(
            id: "reminders.create_list",
            name: "Create Reminder List",
            description: "Create a new reminder list",
            category: "Creating",
            parameters: [
                CommandParameter(name: "name", description: "The name of the new list"),
                CommandParameter(name: "color", description: "The color of the list", required: false),
            ]
        ) { args in
            let name = args["name", default: ""]
            return """
            tell application "Reminders"
                make new list with properties {name:"\(name)"}
                return "Created list: \(name)"
            end tell
            """
        },

        // --- Reading ---
        AppCommand(
            id: "reminders.list_all_lists",
            name: "List All Lists",
            description: "Get the names of all reminder lists",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Reminders"
                return name of every list
            end tell
            """
        },

        AppCommand(
            id: "reminders.list_reminders",
            name: "List Reminders",
            description: "Get all reminders in a list",
            category: "Reading",
            parameters: [
                CommandParameter(name: "list", description: "The name of the reminder list", required: false, defaultValue: "Reminders"),
                CommandParameter(name: "showCompleted", description: "Whether to include completed reminders", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let list = args["list", default: "Reminders"]
            let showCompleted = args["showCompleted", default: "false"] == "true"
            let filter = showCompleted ? "" : " whose completed is false"
            return """
            tell application "Reminders"
                set targetList to list "\(list)"
                set reminderList to {}
                repeat with r in (every reminder of targetList\(filter))
                    set reminderInfo to name of r
                    if due date of r is not missing value then
                        set reminderInfo to reminderInfo & " (due: " & (due date of r as text) & ")"
                    end if
                    if priority of r > 0 then
                        set reminderInfo to reminderInfo & " [priority: " & (priority of r as text) & "]"
                    end if
                    set end of reminderList to reminderInfo
                end repeat
                return reminderList
            end tell
            """
        },

        AppCommand(
            id: "reminders.search_reminders",
            name: "Search Reminders",
            description: "Search for reminders by keyword across all lists",
            category: "Reading",
            parameters: [
                CommandParameter(name: "query", description: "Search keyword"),
            ]
        ) { args in
            let query = args["query", default: ""]
            return """
            tell application "Reminders"
                set results to {}
                repeat with aList in every list
                    repeat with r in (every reminder of aList whose name contains "\(query)")
                        set end of results to (name of aList & ": " & name of r)
                    end repeat
                end repeat
                return results
            end tell
            """
        },

        // --- Updating ---
        AppCommand(
            id: "reminders.complete_reminder",
            name: "Complete Reminder",
            description: "Mark a reminder as completed",
            category: "Updating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the reminder to complete"),
                CommandParameter(name: "list", description: "The reminder list name", required: false, defaultValue: "Reminders"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let list = args["list", default: "Reminders"]
            return """
            tell application "Reminders"
                set targetList to list "\(list)"
                set targetReminder to first reminder of targetList whose name is "\(title)"
                set completed of targetReminder to true
                return "Completed: \(title)"
            end tell
            """
        },

        AppCommand(
            id: "reminders.delete_reminder",
            name: "Delete Reminder",
            description: "Delete a specific reminder",
            category: "Updating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the reminder to delete"),
                CommandParameter(name: "list", description: "The reminder list name", required: false, defaultValue: "Reminders"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let list = args["list", default: "Reminders"]
            return """
            tell application "Reminders"
                set targetList to list "\(list)"
                delete (first reminder of targetList whose name is "\(title)")
                return "Deleted: \(title)"
            end tell
            """
        },

        // --- Counting ---
        AppCommand(
            id: "reminders.count_reminders",
            name: "Count Reminders",
            description: "Count reminders in a list, optionally only incomplete ones",
            category: "Reading",
            parameters: [
                CommandParameter(name: "list", description: "The reminder list name", required: false, defaultValue: "Reminders"),
                CommandParameter(name: "onlyIncomplete", description: "Only count incomplete reminders", required: false, type: .boolean, defaultValue: "true"),
            ]
        ) { args in
            let list = args["list", default: "Reminders"]
            let onlyIncomplete = args["onlyIncomplete", default: "true"] == "true"
            let filter = onlyIncomplete ? " whose completed is false" : ""
            return """
            tell application "Reminders"
                set targetList to list "\(list)"
                return count of (every reminder of targetList\(filter))
            end tell
            """
        },
    ]
}
