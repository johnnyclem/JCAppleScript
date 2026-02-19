import Foundation

/// Shortcut sheet for the Xcode application.
///
/// Provides AppleScript commands for workspace management, scheme actions
/// (build, clean, run, test, debug), project/target introspection, and
/// document access via Xcode's scripting dictionary.
public struct XcodeApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.dt.Xcode"
    public static let appName = "Xcode"
    public static let description = "Apple's integrated development environment for macOS, iOS, watchOS, and tvOS"
    public static let category = AppCategory.development

    public static let commands: [AppCommand] = [
        // --- Workspace ---
        AppCommand(
            id: "xcode.get_active_workspace",
            name: "Get Active Workspace",
            description: "Get the path and name of the active workspace document",
            category: "Workspace",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set ws to active workspace document
                return file of ws as text
            end tell
            """
        },

        AppCommand(
            id: "xcode.open_project",
            name: "Open Project",
            description: "Open an Xcode project or workspace file and wait for it to load",
            category: "Workspace",
            parameters: [
                CommandParameter(name: "path", description: "The full POSIX path to the .xcodeproj or .xcworkspace file", type: .filePath),
                CommandParameter(name: "timeoutSeconds", description: "Seconds to wait for the workspace to load", required: false, type: .integer, defaultValue: "60"),
            ]
        ) { args in
            let path = args["path", default: ""]
            let timeout = args["timeoutSeconds", default: "60"]
            let iterations = (Int(timeout) ?? 60) * 2
            return """
            tell application "Xcode"
                activate
                open "\(path)"
                set wsName to name of active workspace document
                set ws to workspace document wsName
                repeat \(iterations) times
                    if loaded of ws is true then
                        exit repeat
                    end if
                    delay 0.5
                end repeat
                if loaded of ws is false then
                    error "Xcode workspace did not finish loading within timeout."
                end if
                return "Opened: " & wsName
            end tell
            """
        },

        AppCommand(
            id: "xcode.is_workspace_loaded",
            name: "Is Workspace Loaded",
            description: "Check whether the active workspace document has finished loading",
            category: "Workspace",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                return loaded of active workspace document
            end tell
            """
        },

        AppCommand(
            id: "xcode.create_temp_debug_workspace",
            name: "Create Temporary Debugging Workspace",
            description: "Create a new temporary debugging workspace",
            category: "Workspace",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set ws to create temporary debugging workspace
                return file of ws as text
            end tell
            """
        },

        // --- Scheme Actions ---
        AppCommand(
            id: "xcode.build",
            name: "Build",
            description: "Invoke the build scheme action on the active workspace using its current active scheme and run destination. Does not wait for completion; returns a result identifier.",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "waitForCompletion", description: "Whether to wait for the build to complete before returning", required: false, type: .boolean, defaultValue: "true"),
            ]
        ) { args in
            let wait = args["waitForCompletion", default: "true"] == "true"
            if wait {
                return """
                tell application "Xcode"
                    set actionResult to build active workspace document
                    repeat
                        if completed of actionResult is true then
                            exit repeat
                        end if
                        delay 0.5
                    end repeat
                    set s to status of actionResult as text
                    set errMsg to error message of actionResult
                    return "status:" & s & ", error message:" & errMsg
                end tell
                """
            } else {
                return """
                tell application "Xcode"
                    set actionResult to build active workspace document
                    return id of actionResult
                end tell
                """
            }
        },

        AppCommand(
            id: "xcode.clean",
            name: "Clean",
            description: "Invoke the clean scheme action on the active workspace",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "waitForCompletion", description: "Whether to wait for the clean to complete before returning", required: false, type: .boolean, defaultValue: "true"),
            ]
        ) { args in
            let wait = args["waitForCompletion", default: "true"] == "true"
            if wait {
                return """
                tell application "Xcode"
                    set actionResult to clean active workspace document
                    repeat
                        if completed of actionResult is true then
                            exit repeat
                        end if
                        delay 0.5
                    end repeat
                    return status of actionResult as text
                end tell
                """
            } else {
                return """
                tell application "Xcode"
                    set actionResult to clean active workspace document
                    return id of actionResult
                end tell
                """
            }
        },

        AppCommand(
            id: "xcode.run",
            name: "Run",
            description: "Invoke the run scheme action on the active workspace, optionally with command line arguments and environment variables",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "commandLineArguments", description: "Comma-separated command line arguments to pass", required: false),
                CommandParameter(name: "waitForCompletion", description: "Whether to wait for the run to complete before returning", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let cliArgs = args["commandLineArguments", default: ""]
            let wait = args["waitForCompletion", default: "false"] == "true"
            var runCmd: String
            if cliArgs.isEmpty {
                runCmd = "set actionResult to run active workspace document"
            } else {
                let items = cliArgs.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                let listStr = items.joined(separator: ", ")
                runCmd = "set actionResult to run active workspace document with command line arguments {\(listStr)}"
            }
            if wait {
                return """
                tell application "Xcode"
                    \(runCmd)
                    repeat
                        if completed of actionResult is true then
                            exit repeat
                        end if
                        delay 0.5
                    end repeat
                    return status of actionResult as text
                end tell
                """
            } else {
                return """
                tell application "Xcode"
                    \(runCmd)
                    return id of actionResult
                end tell
                """
            }
        },

        AppCommand(
            id: "xcode.test",
            name: "Test",
            description: "Invoke the test scheme action on the active workspace, optionally with command line arguments",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "commandLineArguments", description: "Comma-separated command line arguments to pass", required: false),
                CommandParameter(name: "waitForCompletion", description: "Whether to wait for the tests to complete before returning", required: false, type: .boolean, defaultValue: "true"),
            ]
        ) { args in
            let cliArgs = args["commandLineArguments", default: ""]
            let wait = args["waitForCompletion", default: "true"] == "true"
            var testCmd: String
            if cliArgs.isEmpty {
                testCmd = "set actionResult to test active workspace document"
            } else {
                let items = cliArgs.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                let listStr = items.joined(separator: ", ")
                testCmd = "set actionResult to test active workspace document with command line arguments {\(listStr)}"
            }
            if wait {
                return """
                tell application "Xcode"
                    \(testCmd)
                    repeat
                        if completed of actionResult is true then
                            exit repeat
                        end if
                        delay 0.5
                    end repeat
                    set s to status of actionResult as text
                    set errMsg to error message of actionResult
                    return "status:" & s & ", error message:" & errMsg
                end tell
                """
            } else {
                return """
                tell application "Xcode"
                    \(testCmd)
                    return id of actionResult
                end tell
                """
            }
        },

        AppCommand(
            id: "xcode.stop",
            name: "Stop",
            description: "Stop the active scheme action if one is running",
            category: "Scheme Actions",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                stop active workspace document
            end tell
            """
        },

        AppCommand(
            id: "xcode.debug",
            name: "Debug",
            description: "Start a debugging session using the run scheme action, optionally specifying a scheme, run destination, and whether to skip building",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "scheme", description: "Scheme name to use (defaults to active scheme)", required: false),
                CommandParameter(name: "runDestination", description: "Run destination specifier string (same format as xcodebuild -destination)", required: false),
                CommandParameter(name: "skipBuilding", description: "Whether to perform 'run without building'", required: false, type: .boolean, defaultValue: "false"),
                CommandParameter(name: "commandLineArguments", description: "Comma-separated command line arguments", required: false),
                CommandParameter(name: "waitForCompletion", description: "Whether to wait for the action to complete", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let scheme = args["scheme", default: ""]
            let dest = args["runDestination", default: ""]
            let skip = args["skipBuilding", default: "false"]
            let cliArgs = args["commandLineArguments", default: ""]
            let wait = args["waitForCompletion", default: "false"] == "true"

            var parts: [String] = ["debug active workspace document"]
            if !scheme.isEmpty {
                parts.append("scheme \"\(scheme)\"")
            }
            if !dest.isEmpty {
                parts.append("run destination specifier \"\(dest)\"")
            }
            if skip == "true" {
                parts.append("skip building true")
            }
            if !cliArgs.isEmpty {
                let items = cliArgs.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }
                parts.append("command line arguments {\(items.joined(separator: ", "))}")
            }
            let debugCmd = "set actionResult to " + parts.joined(separator: " ")

            if wait {
                return """
                tell application "Xcode"
                    \(debugCmd)
                    repeat
                        if completed of actionResult is true then
                            exit repeat
                        end if
                        delay 0.5
                    end repeat
                    return status of actionResult as text
                end tell
                """
            } else {
                return """
                tell application "Xcode"
                    \(debugCmd)
                    return id of actionResult
                end tell
                """
            }
        },

        AppCommand(
            id: "xcode.attach_to_process",
            name: "Attach to Process",
            description: "Attach the debugger to a running process by its PID",
            category: "Scheme Actions",
            parameters: [
                CommandParameter(name: "pid", description: "The process identifier (PID) to attach to", type: .integer),
                CommandParameter(name: "suspended", description: "Whether to start debugging in a suspended state", required: false, type: .boolean, defaultValue: "false"),
            ]
        ) { args in
            let pid = args["pid", default: "0"]
            let suspended = args["suspended", default: "false"]
            return """
            tell application "Xcode"
                attach active workspace document to process identifier \(pid) suspended \(suspended)
            end tell
            """
        },

        // --- Scheme Action Results ---
        AppCommand(
            id: "xcode.get_last_action_status",
            name: "Get Last Action Status",
            description: "Get the status and error message of the last scheme action result",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set actionResult to last scheme action result of active workspace document
                set s to status of actionResult as text
                set c to completed of actionResult
                set errMsg to error message of actionResult
                return "status:" & s & ", completed:" & c & ", error message:" & errMsg
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_build_log",
            name: "Get Build Log",
            description: "Get the build log text from the last scheme action",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                return build log of last scheme action result of active workspace document
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_build_errors",
            name: "Get Build Errors",
            description: "Get all build errors from the last scheme action, including file paths and line numbers",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set actionResult to last scheme action result of active workspace document
                set errList to {}
                repeat with e in build errors of actionResult
                    set errInfo to message of e
                    set fp to file path of e
                    set ln to starting line number of e
                    set end of errList to (errInfo & " [" & fp & ":" & ln & "]")
                end repeat
                return errList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_build_warnings",
            name: "Get Build Warnings",
            description: "Get all build warnings from the last scheme action, including file paths and line numbers",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set actionResult to last scheme action result of active workspace document
                set warnList to {}
                repeat with w in build warnings of actionResult
                    set warnInfo to message of w
                    set fp to file path of w
                    set ln to starting line number of w
                    set end of warnList to (warnInfo & " [" & fp & ":" & ln & "]")
                end repeat
                return warnList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_analyzer_issues",
            name: "Get Analyzer Issues",
            description: "Get all static analyzer issues from the last scheme action",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set actionResult to last scheme action result of active workspace document
                set issueList to {}
                repeat with a in analyzer issues of actionResult
                    set issueInfo to message of a
                    set fp to file path of a
                    set ln to starting line number of a
                    set end of issueList to (issueInfo & " [" & fp & ":" & ln & "]")
                end repeat
                return issueList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_test_failures",
            name: "Get Test Failures",
            description: "Get all test failures from the last scheme action",
            category: "Scheme Action Results",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set actionResult to last scheme action result of active workspace document
                set failList to {}
                repeat with f in test failures of actionResult
                    set failInfo to message of f
                    set fp to file path of f
                    set ln to starting line number of f
                    set end of failList to (failInfo & " [" & fp & ":" & ln & "]")
                end repeat
                return failList
            end tell
            """
        },

        // --- Schemes & Run Destinations ---
        AppCommand(
            id: "xcode.list_schemes",
            name: "List Schemes",
            description: "List all schemes in the active workspace with their names and IDs",
            category: "Schemes",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set schemeList to {}
                repeat with s in schemes of active workspace document
                    set end of schemeList to (name of s & " [" & id of s & "]")
                end repeat
                return schemeList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_active_scheme",
            name: "Get Active Scheme",
            description: "Get the name of the currently active scheme",
            category: "Schemes",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                return name of active scheme of active workspace document
            end tell
            """
        },

        AppCommand(
            id: "xcode.set_active_scheme",
            name: "Set Active Scheme",
            description: "Set the active scheme by name",
            category: "Schemes",
            parameters: [
                CommandParameter(name: "scheme", description: "The name of the scheme to activate"),
            ]
        ) { args in
            let scheme = args["scheme", default: ""]
            return """
            tell application "Xcode"
                set ws to active workspace document
                repeat with s in schemes of ws
                    if name of s is "\(scheme)" then
                        set active scheme of ws to s
                        return "Active scheme set to: \(scheme)"
                    end if
                end repeat
                error "Scheme not found: \(scheme)"
            end tell
            """
        },

        AppCommand(
            id: "xcode.list_run_destinations",
            name: "List Run Destinations",
            description: "List all run destinations in the active workspace with name, platform, architecture, and device info",
            category: "Schemes",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set destList to {}
                repeat with d in run destinations of active workspace document
                    set dName to name of d
                    set dArch to architecture of d
                    set dPlat to platform of d
                    set dev to device of d
                    set devName to name of dev
                    set devModel to device model of dev
                    set devOS to operating system version of dev
                    set devGeneric to generic of dev
                    set end of destList to (dName & " | " & dPlat & " | " & dArch & " | " & devModel & " (" & devOS & ")" & " | generic:" & devGeneric)
                end repeat
                return destList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_active_run_destination",
            name: "Get Active Run Destination",
            description: "Get the name and platform of the currently active run destination",
            category: "Schemes",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set d to active run destination of active workspace document
                set dName to name of d
                set dPlat to platform of d
                set dArch to architecture of d
                return dName & " (" & dPlat & ", " & dArch & ")"
            end tell
            """
        },

        // --- Projects & Targets ---
        AppCommand(
            id: "xcode.list_projects",
            name: "List Projects",
            description: "List all projects in the active workspace with their names",
            category: "Projects",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set projList to {}
                repeat with p in projects of active workspace document
                    set end of projList to (name of p & " [" & id of p & "]")
                end repeat
                return projList
            end tell
            """
        },

        AppCommand(
            id: "xcode.list_targets",
            name: "List Targets",
            description: "List all targets for a project in the active workspace",
            category: "Projects",
            parameters: [
                CommandParameter(name: "project", description: "The name of the project"),
            ]
        ) { args in
            let project = args["project", default: ""]
            return """
            tell application "Xcode"
                set targetList to {}
                repeat with t in targets of project "\(project)" of active workspace document
                    set end of targetList to (name of t & " [" & id of t & "]")
                end repeat
                return targetList
            end tell
            """
        },

        AppCommand(
            id: "xcode.list_build_configurations",
            name: "List Build Configurations",
            description: "List all build configurations for a project",
            category: "Projects",
            parameters: [
                CommandParameter(name: "project", description: "The name of the project"),
            ]
        ) { args in
            let project = args["project", default: ""]
            return """
            tell application "Xcode"
                set configList to {}
                repeat with c in build configurations of project "\(project)" of active workspace document
                    set end of configList to name of c
                end repeat
                return configList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_build_setting",
            name: "Get Build Setting",
            description: "Get the resolved value of a build setting for a specific project and build configuration",
            category: "Projects",
            parameters: [
                CommandParameter(name: "project", description: "The name of the project"),
                CommandParameter(name: "configuration", description: "The name of the build configuration (e.g. 'Debug', 'Release')"),
                CommandParameter(name: "setting", description: "The build setting name (e.g. 'PRODUCT_BUNDLE_IDENTIFIER', 'SWIFT_VERSION')"),
            ]
        ) { args in
            let project = args["project", default: ""]
            let config = args["configuration", default: ""]
            let setting = args["setting", default: ""]
            return """
            tell application "Xcode"
                set bc to build configuration "\(config)" of project "\(project)" of active workspace document
                repeat with rs in resolved build settings of bc
                    if name of rs is "\(setting)" then
                        return value of rs
                    end if
                end repeat
                return "missing value"
            end tell
            """
        },

        AppCommand(
            id: "xcode.set_build_setting",
            name: "Set Build Setting",
            description: "Set the value of a build setting for a specific project and build configuration",
            category: "Projects",
            parameters: [
                CommandParameter(name: "project", description: "The name of the project"),
                CommandParameter(name: "configuration", description: "The name of the build configuration (e.g. 'Debug', 'Release')"),
                CommandParameter(name: "setting", description: "The build setting name (e.g. 'PRODUCT_BUNDLE_IDENTIFIER')"),
                CommandParameter(name: "value", description: "The value to set"),
            ]
        ) { args in
            let project = args["project", default: ""]
            let config = args["configuration", default: ""]
            let setting = args["setting", default: ""]
            let value = args["value", default: ""]
            return """
            tell application "Xcode"
                set bc to build configuration "\(config)" of project "\(project)" of active workspace document
                repeat with bs in build settings of bc
                    if name of bs is "\(setting)" then
                        set value of bs to "\(value)"
                        return "Set \(setting) to \(value)"
                    end if
                end repeat
                error "Build setting not found: \(setting)"
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_target_build_configurations",
            name: "Get Target Build Configurations",
            description: "List build configurations for a specific target within a project",
            category: "Projects",
            parameters: [
                CommandParameter(name: "project", description: "The name of the project"),
                CommandParameter(name: "target", description: "The name of the target"),
            ]
        ) { args in
            let project = args["project", default: ""]
            let target = args["target", default: ""]
            return """
            tell application "Xcode"
                set configList to {}
                repeat with c in build configurations of target "\(target)" of project "\(project)" of active workspace document
                    set end of configList to name of c
                end repeat
                return configList
            end tell
            """
        },

        // --- Documents ---
        AppCommand(
            id: "xcode.list_open_documents",
            name: "List Open Documents",
            description: "List all open source documents in Xcode with their paths",
            category: "Documents",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set docList to {}
                repeat with d in source documents
                    set end of docList to path of d
                end repeat
                return docList
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_document_text",
            name: "Get Document Text",
            description: "Get the full text content of an open source document by its path",
            category: "Documents",
            parameters: [
                CommandParameter(name: "path", description: "The file path of the document", type: .filePath),
            ]
        ) { args in
            let path = args["path", default: ""]
            return """
            tell application "Xcode"
                repeat with d in source documents
                    if path of d is "\(path)" then
                        return text of d
                    end if
                end repeat
                error "Document not found: \(path)"
            end tell
            """
        },

        AppCommand(
            id: "xcode.get_selected_text_range",
            name: "Get Selected Text Range",
            description: "Get the selected character and paragraph ranges in the frontmost source document",
            category: "Documents",
            parameters: []
        ) { _ in
            """
            tell application "Xcode"
                set d to source document 1
                set charRange to selected character range of d
                set paraRange to selected paragraph range of d
                return "characters:" & (item 1 of charRange) & "-" & (item 2 of charRange) & ", paragraphs:" & (item 1 of paraRange) & "-" & (item 2 of paraRange)
            end tell
            """
        },
    ]
}
