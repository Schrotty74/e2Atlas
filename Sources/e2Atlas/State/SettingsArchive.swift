import Foundation
import AtlasCore
import AtlasReceiver
import AtlasThemes

/// A portable settings document. Credentials, caches and machine-local bookmarks are never read.
struct SettingsArchive: Codable, Sendable {
    static let maximumBytes = 4 * 1024 * 1024
    static let builtinThemeIDs: Set<String> = ["system", "ocean", "ivory", "bronze"]
    var format = "e2Atlas-settings"
    var version = 1
    let preferences: AppPreferences
    let themes: [AtlasTheme]

    init(preferences: AppPreferences, themes: [AtlasTheme]) throws {
        self.preferences = preferences
        self.themes = themes.filter { !Self.builtinThemeIDs.contains($0.id) }
        try validate()
    }

    static func decode(_ data: Data) throws -> SettingsArchive {
        do {
            guard data.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
            let archive = try JSONDecoder().decode(Self.self, from: data)
            try archive.validate()
            return archive
        } catch { throw AtlasFailure.storage("Die Datei ist keine gültige e2Atlas-Einstellungssicherung oder verwendet ein nicht unterstütztes Format.") }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw AtlasFailure.storage("Die Einstellungssicherung ist zu groß.") }
        return data
    }

    private func validate() throws {
        guard format == "e2Atlas-settings", version == 1, themes.count <= 64,
              Set(themes.map(\.id)).count == themes.count,
              !preferences.themeID.isEmpty, preferences.themeID.count <= 48,
              preferences.shortcuts.count <= 100,
              preferences.epgUpdateIntervalMinutes.map({ (0...10080).contains($0) }) ?? true,
              preferences.epgRefreshStartDate.map({ $0.timeIntervalSince1970.isFinite }) ?? true
        else { throw AtlasFailure.invalidResponse }
        try PreferencesStore.validate(preferences)
        for profile in preferences.receivers { _ = try ReceiverAddress.resolve(profile.address) }
        for theme in themes {
            guard !Self.builtinThemeIDs.contains(theme.id) else { throw AtlasFailure.invalidResponse }
            let data = try JSONEncoder().encode(theme)
            guard data.count <= 65_536 else { throw AtlasFailure.invalidResponse }
            _ = try AtlasTheme.decode(data)
        }
    }
}

struct SettingsImportPlan: Identifiable, Sendable {
    let id = UUID()
    let originalPreferences: AppPreferences
    let originalThemes: [AtlasTheme]
    let preferences: AppPreferences
    let themesToAdd: [AtlasTheme]
    let addedReceiverCount: Int
    let addedFavoriteCount: Int
    let addedPresetCount: Int

    init(archive: SettingsArchive, current: AppPreferences, existingThemes: [AtlasTheme]) throws {
        // Revalidate even if a caller constructed the value in memory.
        _ = try archive.encoded()
        try PreferencesStore.validate(current)
        originalPreferences = current; originalThemes = existingThemes
        var result = archive.preferences
        result.receivers = current.receivers
        var mapping: [UUID: UUID] = [:]
        for source in archive.preferences.receivers {
            // Only an exact connection match may keep an existing Keychain association.
            let matches = result.receivers.filter { Self.connectionKey($0) == Self.connectionKey(source) }
            if let match = matches.first(where: { $0.id == source.id }) ?? matches.first {
                mapping[source.id] = match.id
            } else {
                var profile = source; profile.id = UUID()
                mapping[source.id] = profile.id; result.receivers.append(profile)
            }
        }
        guard result.receivers.count <= 3 else {
            throw AtlasFailure.storage("Der Import würde mehr als drei Receiver ergeben. Entferne zuerst ein nicht mehr benötigtes Profil.")
        }
        result.selectedReceiverID = archive.preferences.selectedReceiverID.flatMap { mapping[$0] }
            ?? current.selectedReceiverID ?? result.receivers.first?.id
        var favorites = current.favoriteChannels ?? []
        for source in archive.preferences.favoriteChannels ?? [] {
            guard let receiverID = mapping[source.receiverID] else { throw AtlasFailure.invalidResponse }
            let favorite = FavoriteChannel(receiverID: receiverID, channel: source.channel)
            if !favorites.contains(where: { $0.id == favorite.id }) { favorites.append(favorite) }
        }
        result.favoriteChannels = favorites
        var presets = current.multiviewPresets ?? []
        for source in archive.preferences.multiviewPresets ?? [] {
            guard let receiverID = mapping[source.receiverID] else { throw AtlasFailure.invalidResponse }
            let duplicate = presets.contains {
                $0.receiverID == receiverID && $0.name == source.name && $0.channels == source.channels
                    && $0.audibleIndex == source.audibleIndex && $0.volume == source.volume && $0.isMuted == source.isMuted
            }
            if !duplicate {
                var preset = source; preset.id = UUID(); preset.receiverID = receiverID; presets.append(preset)
            }
        }
        result.multiviewPresets = presets
        guard favorites.count <= 300, presets.count <= 30 else {
            throw AtlasFailure.storage("Der Import würde die Grenze von 300 Favoriten oder 30 Multiview-Belegungen überschreiten.")
        }

        var knownThemes = existingThemes
        var additions: [AtlasTheme] = []
        var themeMapping: [String: String] = [:]
        for source in archive.themes {
            var theme = source
            if let same = knownThemes.first(where: { candidate in
                var comparable = candidate; comparable.id = source.id
                return comparable == source
            }) { themeMapping[source.id] = same.id; continue }
            // Renaming an ID never overwrites a user's existing theme file.
            var suffix = 1
            while knownThemes.contains(where: { $0.id == theme.id }) {
                let ending = "-import-\(suffix)"
                theme.id = String(source.id.prefix(48 - ending.count)) + ending; suffix += 1
            }
            themeMapping[source.id] = theme.id
            knownThemes.append(theme); additions.append(theme)
        }
        result.themeID = themeMapping[archive.preferences.themeID] ?? archive.preferences.themeID
        if !knownThemes.contains(where: { $0.id == result.themeID }) { result.themeID = "system" }
        try PreferencesStore.validate(result)
        preferences = result; themesToAdd = additions
        addedReceiverCount = result.receivers.count - current.receivers.count
        addedFavoriteCount = favorites.count - (current.favoriteChannels ?? []).count
        addedPresetCount = presets.count - (current.multiviewPresets ?? []).count
    }

    private static func connectionKey(_ profile: ReceiverProfile) -> String {
        guard let url = try? ReceiverAddress.resolve(profile.address), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "invalid:" + profile.id.uuidString
        }
        // Include scheme, explicit/effective port and username; never reuse a secret at another origin.
        let scheme = parts.scheme?.lowercased() ?? ""
        let port = parts.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)|\(parts.host?.lowercased() ?? "")|\(port)|\(profile.username)|\(profile.streamPort)"
    }

    /// A failed settings write rolls back only files created by this import.
    func install(settingsURL: URL, themeDirectory: URL) throws {
        var created: [URL] = []
        let manager = FileManager.default
        let madeDirectory = !manager.fileExists(atPath: themeDirectory.path)
        let staging = themeDirectory.appendingPathComponent(".settings-import-\(UUID().uuidString)", isDirectory: true)
        var madeStaging = false
        defer { if madeStaging { try? manager.removeItem(at: staging) } }
        do {
            if !themesToAdd.isEmpty {
                try manager.createDirectory(at: themeDirectory, withIntermediateDirectories: true)
                try manager.createDirectory(at: staging, withIntermediateDirectories: false)
                madeStaging = true
                for theme in themesToAdd {
                    let url = themeDirectory.appendingPathComponent("import-\(UUID().uuidString).json")
                    let stagedFile = staging.appendingPathComponent(url.lastPathComponent)
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    try encoder.encode(theme).write(to: stagedFile, options: .atomic)
                    try manager.moveItem(at: stagedFile, to: url)
                    created.append(url)
                }
            }
            try PreferencesStore(fileURL: settingsURL).save(preferences)
        } catch {
            for url in created { try? manager.removeItem(at: url) }
            if madeStaging { try? manager.removeItem(at: staging); madeStaging = false }
            if madeDirectory, (try? manager.contentsOfDirectory(atPath: themeDirectory.path).isEmpty) == true {
                try? manager.removeItem(at: themeDirectory)
            }
            throw AtlasFailure.storage("Die Einstellungen konnten nicht importiert werden. Vorhandene Einstellungen und Themes bleiben erhalten.")
        }
    }
}

actor SettingsArchiveReader {
    func read(_ url: URL) throws -> SettingsArchive {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: SettingsArchive.maximumBytes + 1) ?? Data()
        return try SettingsArchive.decode(data)
    }
}
