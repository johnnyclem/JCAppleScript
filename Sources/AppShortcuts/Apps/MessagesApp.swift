import Foundation

/// Shortcut sheet for the macOS Messages application.
///
/// Provides AppleScript commands for sending iMessages and SMS,
/// reading conversations, and managing chats.
public struct MessagesApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.MobileSMS"
    public static let appName = "Messages"
    public static let description = "Send and receive iMessages and SMS/MMS text messages"
    public static let category = AppCategory.communication

    public static let commands: [AppCommand] = [
        // --- Sending ---
        AppCommand(
            id: "messages.send_message",
            name: "Send Message",
            description: "Send a text message to a recipient via iMessage or SMS",
            category: "Sending",
            parameters: [
                CommandParameter(name: "recipient", description: "Phone number or email address of the recipient"),
                CommandParameter(name: "message", description: "The text message to send"),
                CommandParameter(name: "service", description: "The messaging service to use", required: false, defaultValue: "iMessage", allowedValues: ["iMessage", "SMS"]),
            ]
        ) { args in
            let recipient = args["recipient", default: ""]
            let message = args["message", default: ""]
            let service = args["service", default: "iMessage"]
            return """
            tell application "Messages"
                set targetService to 1st service whose service type = \(service == "iMessage" ? "iMessage" : "SMS")
                set targetBuddy to buddy "\(recipient)" of targetService
                send "\(message)" to targetBuddy
            end tell
            """
        },

        AppCommand(
            id: "messages.send_file",
            name: "Send File",
            description: "Send a file attachment to a recipient",
            category: "Sending",
            parameters: [
                CommandParameter(name: "recipient", description: "Phone number or email address of the recipient"),
                CommandParameter(name: "filePath", description: "POSIX path to the file to send", type: .filePath),
                CommandParameter(name: "service", description: "The messaging service to use", required: false, defaultValue: "iMessage", allowedValues: ["iMessage", "SMS"]),
            ]
        ) { args in
            let recipient = args["recipient", default: ""]
            let filePath = args["filePath", default: ""]
            let service = args["service", default: "iMessage"]
            return """
            tell application "Messages"
                set targetService to 1st service whose service type = \(service == "iMessage" ? "iMessage" : "SMS")
                set targetBuddy to buddy "\(recipient)" of targetService
                send POSIX file "\(filePath)" to targetBuddy
            end tell
            """
        },

        // --- Reading ---
        AppCommand(
            id: "messages.list_chats",
            name: "List Chats",
            description: "Get a list of all chat conversations",
            category: "Reading",
            parameters: []
        ) { _ in
            """
            tell application "Messages"
                set chatList to {}
                repeat with aChat in chats
                    set end of chatList to (id of aChat & ": " & name of aChat)
                end repeat
                return chatList
            end tell
            """
        },

        AppCommand(
            id: "messages.get_chat_messages",
            name: "Get Chat Messages",
            description: "Retrieve recent messages from a specific chat",
            category: "Reading",
            parameters: [
                CommandParameter(name: "chatId", description: "The ID of the chat to read messages from"),
                CommandParameter(name: "count", description: "Number of recent messages to retrieve", required: false, type: .integer, defaultValue: "10"),
            ]
        ) { args in
            let chatId = args["chatId", default: ""]
            let count = args["count", default: "10"]
            return """
            tell application "Messages"
                set targetChat to chat id "\(chatId)"
                set msgList to {}
                set msgCount to count of messages of targetChat
                set startIdx to msgCount - \(count) + 1
                if startIdx < 1 then set startIdx to 1
                repeat with i from startIdx to msgCount
                    set msg to message i of targetChat
                    set senderName to handle of sender of msg
                    set msgText to text of msg
                    set msgDate to date sent of msg
                    set end of msgList to (senderName & " [" & (msgDate as text) & "]: " & msgText)
                end repeat
                return msgList
            end tell
            """
        },

        AppCommand(
            id: "messages.get_participants",
            name: "Get Chat Participants",
            description: "List all participants in a chat",
            category: "Reading",
            parameters: [
                CommandParameter(name: "chatId", description: "The ID of the chat"),
            ]
        ) { args in
            let chatId = args["chatId", default: ""]
            return """
            tell application "Messages"
                set targetChat to chat id "\(chatId)"
                set participantList to {}
                repeat with p in participants of targetChat
                    set end of participantList to (handle of p & " (" & name of p & ")")
                end repeat
                return participantList
            end tell
            """
        },

        // --- Status ---
        AppCommand(
            id: "messages.set_status",
            name: "Set Status Message",
            description: "Set your status message in Messages",
            category: "Status",
            parameters: [
                CommandParameter(name: "status", description: "The status message text"),
            ]
        ) { args in
            let status = args["status", default: ""]
            return """
            tell application "Messages"
                set status message to "\(status)"
            end tell
            """
        },

        AppCommand(
            id: "messages.get_status",
            name: "Get Status Message",
            description: "Get your current status message",
            category: "Status",
            parameters: []
        ) { _ in
            """
            tell application "Messages"
                return status message
            end tell
            """
        },
    ]
}
