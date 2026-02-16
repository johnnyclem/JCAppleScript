import Foundation

/// Shortcut sheet for the macOS Mail application.
///
/// Provides AppleScript commands for composing, reading, searching,
/// and managing emails.
public struct MailApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.mail"
    public static let appName = "Mail"
    public static let description = "Apple's email client - send, receive, and manage email"
    public static let category = AppCategory.communication

    public static let commands: [AppCommand] = [
        // --- Composing ---
        AppCommand(
            id: "mail.compose_message",
            name: "Compose Message",
            description: "Create a new email message",
            category: "Composing",
            parameters: [
                CommandParameter(name: "to", description: "Recipient email address"),
                CommandParameter(name: "subject", description: "Email subject line"),
                CommandParameter(name: "body", description: "Email body text"),
                CommandParameter(name: "cc", description: "CC recipients (comma-separated)", required: false),
                CommandParameter(name: "bcc", description: "BCC recipients (comma-separated)", required: false),
                CommandParameter(name: "send", description: "Whether to send immediately or just compose", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let to = args["to", default: ""]
            let subject = args["subject", default: ""]
            let body = args["body", default: ""]
            let cc = args["cc"]
            let send = args["send", default: "false"] == "true"

            var script = """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
                tell newMessage
                    make new to recipient at end of to recipients with properties {address:"\(to)"}
            """
            if let cc = cc {
                for addr in cc.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                    script += """

                        make new cc recipient at end of cc recipients with properties {address:"\(addr)"}
                    """
                }
            }
            script += """

                end tell
            """
            if send {
                script += """

                    send newMessage
                """
            }
            script += """

                activate
            end tell
            """
            return script
        },

        AppCommand(
            id: "mail.compose_with_attachment",
            name: "Compose with Attachment",
            description: "Create a new email with a file attachment",
            category: "Composing",
            parameters: [
                CommandParameter(name: "to", description: "Recipient email address"),
                CommandParameter(name: "subject", description: "Email subject line"),
                CommandParameter(name: "body", description: "Email body text"),
                CommandParameter(name: "attachmentPath", description: "POSIX path to the file to attach", type: .filePath),
            ]
        ) { args in
            let to = args["to", default: ""]
            let subject = args["subject", default: ""]
            let body = args["body", default: ""]
            let attachmentPath = args["attachmentPath", default: ""]
            return """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
                tell newMessage
                    make new to recipient at end of to recipients with properties {address:"\(to)"}
                    make new attachment with properties {file name:"\(attachmentPath)"} at after the last paragraph
                end tell
                activate
            end tell
            """
        },

        // --- Reading ---
        AppCommand(
            id: "mail.get_unread_count",
            name: "Get Unread Count",
            description: "Get the number of unread messages across all accounts or a specific mailbox",
            category: "Reading",
            parameters: [
                CommandParameter(name: "mailbox", description: "Name of the mailbox (e.g. 'INBOX')", required: false, defaultValue: "INBOX"),
            ]
        ) { args in
            let mailbox = args["mailbox", default: "INBOX"]
            return """
            tell application "Mail"
                set totalUnread to 0
                repeat with acct in accounts
                    try
                        set totalUnread to totalUnread + (unread count of mailbox "\(mailbox)" of acct)
                    end try
                end repeat
                return totalUnread
            end tell
            """
        },

        AppCommand(
            id: "mail.list_recent_messages",
            name: "List Recent Messages",
            description: "List recent messages from a mailbox",
            category: "Reading",
            parameters: [
                CommandParameter(name: "count", description: "Number of messages to retrieve", required: false, type: .integer, defaultValue: "10"),
                CommandParameter(name: "mailbox", description: "Mailbox name", required: false, defaultValue: "INBOX"),
            ]
        ) { args in
            let count = args["count", default: "10"]
            let mailbox = args["mailbox", default: "INBOX"]
            return """
            tell application "Mail"
                set msgList to {}
                repeat with acct in accounts
                    try
                        set msgs to messages of mailbox "\(mailbox)" of acct
                        set msgCount to count of msgs
                        set startIdx to msgCount - \(count) + 1
                        if startIdx < 1 then set startIdx to 1
                        repeat with i from startIdx to msgCount
                            set msg to item i of msgs
                            set msgInfo to (sender of msg & " | " & subject of msg & " | " & (date received of msg as text))
                            set end of msgList to msgInfo
                        end repeat
                    end try
                end repeat
                return msgList
            end tell
            """
        },

        AppCommand(
            id: "mail.search_messages",
            name: "Search Messages",
            description: "Search for messages matching a query in subject or sender",
            category: "Reading",
            parameters: [
                CommandParameter(name: "query", description: "Search text to match against subject or sender"),
            ]
        ) { args in
            let query = args["query", default: ""]
            return """
            tell application "Mail"
                set results to {}
                repeat with acct in accounts
                    try
                        set msgs to (messages of mailbox "INBOX" of acct whose subject contains "\(query)" or sender contains "\(query)")
                        repeat with msg in msgs
                            set end of results to (sender of msg & " | " & subject of msg & " | " & (date received of msg as text))
                        end repeat
                    end try
                end repeat
                return results
            end tell
            """
        },

        // --- Accounts ---
        AppCommand(
            id: "mail.list_accounts",
            name: "List Accounts",
            description: "Get a list of all configured email accounts",
            category: "Accounts",
            parameters: []
        ) { _ in
            """
            tell application "Mail"
                set accountList to {}
                repeat with acct in accounts
                    set end of accountList to (name of acct & " (" & email addresses of acct & ")")
                end repeat
                return accountList
            end tell
            """
        },

        AppCommand(
            id: "mail.list_mailboxes",
            name: "List Mailboxes",
            description: "List all mailboxes for all accounts",
            category: "Accounts",
            parameters: []
        ) { _ in
            """
            tell application "Mail"
                set mbList to {}
                repeat with acct in accounts
                    repeat with mb in mailboxes of acct
                        set end of mbList to (name of acct & "/" & name of mb)
                    end repeat
                end repeat
                return mbList
            end tell
            """
        },

        // --- Management ---
        AppCommand(
            id: "mail.check_for_new_mail",
            name: "Check for New Mail",
            description: "Force check for new mail across all accounts",
            category: "Management",
            parameters: []
        ) { _ in
            """
            tell application "Mail"
                check for new mail
                return "Checking for new mail..."
            end tell
            """
        },
    ]
}
