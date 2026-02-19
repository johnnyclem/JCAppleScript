import Foundation

/// Shortcut sheet for the macOS Speech Recognition Suite.
///
/// Provides AppleScript commands for listening for spoken phrases
/// using the system speech recognition engine.
public struct SpeechRecognitionApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.speech.recognitionserver"
    public static let appName = "Speech Recognition Server"
    public static let description = "macOS speech recognition - listen for spoken phrases via AppleScript"
    public static let category = AppCategory.system

    public static let commands: [AppCommand] = [
        // --- Listening ---
        AppCommand(
            id: "speech.listen_for",
            name: "Listen For",
            description: "Listen for a single spoken phrase from a list of possible phrases and return the recognized result",
            category: "Listening",
            parameters: [
                CommandParameter(name: "phrases", description: "Comma-separated list of possible phrases to listen for (e.g. 'yes,no,maybe')"),
                CommandParameter(name: "prompt", description: "Text the computer will speak as a prompt", required: false),
                CommandParameter(name: "givingUpAfter", description: "Seconds to wait before giving up", required: false, type: .integer),
                CommandParameter(name: "filtering", description: "Whether to skip phrases with special characters", required: false, type: .boolean),
                CommandParameter(name: "displaying", description: "Comma-separated list of display labels for the commands (overrides the phrase list in the UI)", required: false),
            ]
        ) { args in
            let phrases = args["phrases", default: ""]
            let items = phrases.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
            let listStr = items.joined(separator: ", ")

            var parts: [String] = ["listen for {\(listStr)}"]
            if let prompt = args["prompt"], !prompt.isEmpty {
                parts.append("with prompt \"\(prompt)\"")
            }
            if let timeout = args["givingUpAfter"], !timeout.isEmpty {
                parts.append("giving up after \(timeout)")
            }
            if let filtering = args["filtering"], !filtering.isEmpty {
                parts.append("filtering \(filtering)")
            }
            if let displaying = args["displaying"], !displaying.isEmpty {
                let displayItems = displaying.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                parts.append("displaying {\(displayItems.joined(separator: ", "))}")
            }

            return parts.joined(separator: " ")
        },

        AppCommand(
            id: "speech.listen_continuously",
            name: "Listen Continuously",
            description: "Listen continuously for spoken phrases from a list. Call 'Stop Listening' with the same identifier when done.",
            category: "Listening",
            parameters: [
                CommandParameter(name: "phrases", description: "Comma-separated list of possible phrases to listen for"),
                CommandParameter(name: "identifier", description: "A unique identifier string for this recognizer"),
                CommandParameter(name: "prompt", description: "Text the computer will speak as a prompt", required: false),
                CommandParameter(name: "givingUpAfter", description: "Seconds to wait before giving up", required: false, type: .integer),
                CommandParameter(name: "filtering", description: "Whether to skip phrases with special characters", required: false, type: .boolean),
                CommandParameter(name: "sectionTitle", description: "A section title under which the commands will be listed", required: false),
                CommandParameter(name: "displaying", description: "Comma-separated list of display labels for the commands", required: false),
            ]
        ) { args in
            let phrases = args["phrases", default: ""]
            let identifier = args["identifier", default: ""]
            let items = phrases.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
            let listStr = items.joined(separator: ", ")

            var parts: [String] = ["listen continuously for {\(listStr)}"]
            if let prompt = args["prompt"], !prompt.isEmpty {
                parts.append("with prompt \"\(prompt)\"")
            }
            if let timeout = args["givingUpAfter"], !timeout.isEmpty {
                parts.append("giving up after \(timeout)")
            }
            if let filtering = args["filtering"], !filtering.isEmpty {
                parts.append("filtering \(filtering)")
            }
            if !identifier.isEmpty {
                parts.append("with identifier \"\(identifier)\"")
            }
            if let sectionTitle = args["sectionTitle"], !sectionTitle.isEmpty {
                parts.append("with section title \"\(sectionTitle)\"")
            }
            if let displaying = args["displaying"], !displaying.isEmpty {
                let displayItems = displaying.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                parts.append("displaying {\(displayItems.joined(separator: ", "))}")
            }

            return parts.joined(separator: " ")
        },

        AppCommand(
            id: "speech.stop_listening",
            name: "Stop Listening",
            description: "Stop a continuous listening session by its unique identifier",
            category: "Listening",
            parameters: [
                CommandParameter(name: "identifier", description: "The unique identifier string of the recognizer to stop"),
            ]
        ) { args in
            let identifier = args["identifier", default: ""]
            return "stop listening for identifier \"\(identifier)\""
        },
    ]
}
