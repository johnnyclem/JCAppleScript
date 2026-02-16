import Foundation

/// Shortcut sheet for the macOS Music application.
///
/// Provides AppleScript commands for playback control, playlist management,
/// and library browsing.
public struct MusicApp: ScriptableApp {
    public static let bundleIdentifier = "com.apple.Music"
    public static let appName = "Music"
    public static let description = "Apple Music player - play, browse, and manage your music library"
    public static let category = AppCategory.media

    public static let commands: [AppCommand] = [
        // --- Playback ---
        AppCommand(
            id: "music.play",
            name: "Play",
            description: "Start or resume playback",
            category: "Playback",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                play
                return "Playing"
            end tell
            """
        },

        AppCommand(
            id: "music.pause",
            name: "Pause",
            description: "Pause playback",
            category: "Playback",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                pause
                return "Paused"
            end tell
            """
        },

        AppCommand(
            id: "music.next_track",
            name: "Next Track",
            description: "Skip to the next track",
            category: "Playback",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                next track
                delay 0.5
                return "Now playing: " & name of current track & " by " & artist of current track
            end tell
            """
        },

        AppCommand(
            id: "music.previous_track",
            name: "Previous Track",
            description: "Go back to the previous track",
            category: "Playback",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                previous track
                delay 0.5
                return "Now playing: " & name of current track & " by " & artist of current track
            end tell
            """
        },

        AppCommand(
            id: "music.set_volume",
            name: "Set Volume",
            description: "Set the playback volume (0-100)",
            category: "Playback",
            parameters: [
                CommandParameter(name: "volume", description: "Volume level from 0 to 100", type: .integer),
            ]
        ) { args in
            let volume = args["volume", default: "50"]
            return """
            tell application "Music"
                set sound volume to \(volume)
                return "Volume set to \(volume)"
            end tell
            """
        },

        AppCommand(
            id: "music.toggle_shuffle",
            name: "Toggle Shuffle",
            description: "Toggle shuffle mode on or off",
            category: "Playback",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                set shuffle enabled to not shuffle enabled
                if shuffle enabled then
                    return "Shuffle: ON"
                else
                    return "Shuffle: OFF"
                end if
            end tell
            """
        },

        AppCommand(
            id: "music.set_repeat",
            name: "Set Repeat Mode",
            description: "Set the repeat mode",
            category: "Playback",
            parameters: [
                CommandParameter(name: "mode", description: "Repeat mode", allowedValues: ["off", "one", "all"]),
            ]
        ) { args in
            let mode = args["mode", default: "off"]
            return """
            tell application "Music"
                set song repeat to \(mode)
                return "Repeat mode: \(mode)"
            end tell
            """
        },

        // --- Current Track ---
        AppCommand(
            id: "music.get_current_track",
            name: "Get Current Track",
            description: "Get information about the currently playing track",
            category: "Current Track",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to duration of current track
                    set trackPosition to player position
                    set playerStatus to player state as text
                    return "Track: " & trackName & return & "Artist: " & trackArtist & return & "Album: " & trackAlbum & return & "Status: " & playerStatus & return & "Position: " & (trackPosition as text) & "s / " & (trackDuration as text) & "s"
                else
                    return "No track currently playing"
                end if
            end tell
            """
        },

        // --- Playlists ---
        AppCommand(
            id: "music.list_playlists",
            name: "List Playlists",
            description: "Get the names of all playlists",
            category: "Playlists",
            parameters: []
        ) { _ in
            """
            tell application "Music"
                return name of every playlist
            end tell
            """
        },

        AppCommand(
            id: "music.play_playlist",
            name: "Play Playlist",
            description: "Start playing a specific playlist",
            category: "Playlists",
            parameters: [
                CommandParameter(name: "name", description: "The name of the playlist"),
            ]
        ) { args in
            let name = args["name", default: ""]
            return """
            tell application "Music"
                play playlist "\(name)"
                return "Playing playlist: \(name)"
            end tell
            """
        },

        AppCommand(
            id: "music.create_playlist",
            name: "Create Playlist",
            description: "Create a new empty playlist",
            category: "Playlists",
            parameters: [
                CommandParameter(name: "name", description: "The name of the new playlist"),
            ]
        ) { args in
            let name = args["name", default: ""]
            return """
            tell application "Music"
                make new playlist with properties {name:"\(name)"}
                return "Created playlist: \(name)"
            end tell
            """
        },

        // --- Search ---
        AppCommand(
            id: "music.search_library",
            name: "Search Library",
            description: "Search the music library by name",
            category: "Library",
            parameters: [
                CommandParameter(name: "query", description: "Search text"),
            ]
        ) { args in
            let query = args["query", default: ""]
            return """
            tell application "Music"
                set results to (search playlist "Library" for "\(query)")
                set resultList to {}
                repeat with t in results
                    set end of resultList to (name of t & " - " & artist of t & " (" & album of t & ")")
                end repeat
                return resultList
            end tell
            """
        },

        // --- Rating ---
        AppCommand(
            id: "music.rate_current_track",
            name: "Rate Current Track",
            description: "Set the rating for the current track (0-100, in increments of 20)",
            category: "Library",
            parameters: [
                CommandParameter(name: "rating", description: "Rating value: 0, 20, 40, 60, 80, or 100", type: .integer, allowedValues: ["0", "20", "40", "60", "80", "100"]),
            ]
        ) { args in
            let rating = args["rating", default: "0"]
            return """
            tell application "Music"
                set rating of current track to \(rating)
                return "Rated current track: " & (\(rating) / 20) & " stars"
            end tell
            """
        },
    ]
}
