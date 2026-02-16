import Foundation

/// Shortcut sheet for the macOS Calendar application.
///
/// Provides AppleScript commands for creating, reading, and managing
/// calendar events and calendars.
public struct CalendarApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.iCal"
    public static let appName = "Calendar"
    public static let description = "Manage calendars, events, and schedules"
    public static let category = AppCategory.productivity

    public static let commands: [AppCommand] = [
        // --- Creating ---
        AppCommand(
            id: "calendar.create_event",
            name: "Create Event",
            description: "Create a new calendar event",
            category: "Creating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the event"),
                CommandParameter(name: "startDate", description: "Start date and time (e.g. 'March 15, 2025 2:00 PM')", type: .date),
                CommandParameter(name: "endDate", description: "End date and time", type: .date),
                CommandParameter(name: "calendar", description: "The name of the calendar to add the event to", required: false, defaultValue: "Calendar"),
                CommandParameter(name: "location", description: "Event location", required: false),
                CommandParameter(name: "notes", description: "Event notes", required: false),
                CommandParameter(name: "allDay", description: "Whether this is an all-day event", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let startDate = args["startDate", default: ""]
            let endDate = args["endDate", default: ""]
            let calendar = args["calendar", default: "Calendar"]
            let location = args["location"]
            let notes = args["notes"]
            let allDay = args["allDay", default: "false"] == "true"

            var props = "summary:\"\(title)\", start date:date \"\(startDate)\", end date:date \"\(endDate)\""
            if allDay { props += ", allday event:true" }
            if let location = location { props += ", location:\"\(location)\"" }
            if let notes = notes { props += ", description:\"\(notes)\"" }

            return """
            tell application "Calendar"
                tell calendar "\(calendar)"
                    make new event at end with properties {\(props)}
                end tell
                return "Event created: \(title)"
            end tell
            """
        },

        // --- Reading ---
        AppCommand(
            id: "calendar.list_calendars",
            name: "List Calendars",
            description: "Get the names of all calendars",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Calendar"
                return name of every calendar
            end tell
            """
        },

        AppCommand(
            id: "calendar.list_todays_events",
            name: "List Today's Events",
            description: "Get all events scheduled for today",
            category: "Reading",
            parameters: [
                CommandParameter(name: "calendar", description: "Calendar name (leave empty for all)", required: false),
            ]
        ) { args in
            let calendar = args["calendar"]
            let calFilter = calendar.map { "of calendar \"\($0)\" " } ?? ""
            return """
            tell application "Calendar"
                set todayStart to current date
                set time of todayStart to 0
                set todayEnd to todayStart + (1 * days)
                set eventList to {}
                set todayEvents to (every event \(calFilter)whose start date ≥ todayStart and start date < todayEnd)
                repeat with evt in todayEvents
                    set evtInfo to summary of evt & " | " & (start date of evt as text) & " - " & (end date of evt as text)
                    if location of evt is not missing value and location of evt is not "" then
                        set evtInfo to evtInfo & " @ " & location of evt
                    end if
                    set end of eventList to evtInfo
                end repeat
                return eventList
            end tell
            """
        },

        AppCommand(
            id: "calendar.list_upcoming_events",
            name: "List Upcoming Events",
            description: "Get events in the next N days",
            category: "Reading",
            parameters: [
                CommandParameter(name: "days", description: "Number of days to look ahead", required: false, type: .integer, defaultValue: "7"),
            ]
        ) { args in
            let days = args["days", default: "7"]
            return """
            tell application "Calendar"
                set todayStart to current date
                set time of todayStart to 0
                set futureDate to todayStart + (\(days) * days)
                set eventList to {}
                set upcomingEvents to (every event whose start date ≥ todayStart and start date < futureDate)
                repeat with evt in upcomingEvents
                    set evtInfo to summary of evt & " | " & (start date of evt as text) & " - " & (end date of evt as text)
                    set end of eventList to evtInfo
                end repeat
                return eventList
            end tell
            """
        },

        // --- Updating ---
        AppCommand(
            id: "calendar.delete_event",
            name: "Delete Event",
            description: "Delete a calendar event by title (deletes the first match)",
            category: "Updating",
            parameters: [
                CommandParameter(name: "title", description: "The title of the event to delete"),
                CommandParameter(name: "calendar", description: "The calendar name", required: false, defaultValue: "Calendar"),
            ]
        ) { args in
            let title = args["title", default: ""]
            let calendar = args["calendar", default: "Calendar"]
            return """
            tell application "Calendar"
                tell calendar "\(calendar)"
                    set targetEvents to (every event whose summary is "\(title)")
                    if (count of targetEvents) > 0 then
                        delete item 1 of targetEvents
                        return "Deleted event: \(title)"
                    else
                        return "No event found with title: \(title)"
                    end if
                end tell
            end tell
            """
        },

        // --- View ---
        AppCommand(
            id: "calendar.switch_view",
            name: "Switch View",
            description: "Switch the calendar view mode",
            category: "View",
            parameters: [
                CommandParameter(name: "view", description: "The view to switch to", allowedValues: ["day view", "week view", "month view", "year view"]),
            ]
        ) { args in
            let view = args["view", default: "week view"]
            return """
            tell application "Calendar"
                switch view to \(view)
                activate
            end tell
            """
        },
    ]
}
