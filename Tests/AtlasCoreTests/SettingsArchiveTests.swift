#if !SWIFT_PACKAGE
import Foundation
import Testing
import AtlasCore
import AtlasThemes

@Suite("Portable settings archive")
struct SettingsArchiveTests {
    private func fixture() throws -> AppPreferences {
        var prefs = AppPreferences()
        let profile = ReceiverProfile(name: "Synthetic receiver", address: "receiver.example", username: "viewer")
        try prefs.upsert(profile)
        prefs.language = .english; prefs.appearance = .dark
        prefs.epgUpdateIntervalMinutes = 90
        prefs.epgRefreshStartDate = Date(timeIntervalSince1970: 1_800_000_000)
        prefs.autoConnectOnLaunch = false
        let channel = Channel(id: "synthetic-service", name: "Synthetic channel")
        prefs.toggleFavorite(channel, receiverID: profile.id)
        prefs.multiviewPresets = [MultiviewPreset(name: "Synthetic layout", receiverID: profile.id, channels: [channel, nil], audibleIndex: 0, volume: 0.4, isMuted: true)]
        return prefs
    }

    private func customTheme() -> AtlasTheme {
        var theme = AtlasTheme.system; theme.id = "custom-example"; theme.name = "Synthetic theme"
        return theme
    }

    @Test func roundTripIncludesPortableOptionsAndThemesOnly() throws {
        let prefs = try fixture()
        let archive = try SettingsArchive(preferences: prefs, themes: [.system, customTheme()])
        let data = try archive.encoded()
        let restored = try SettingsArchive.decode(data)
        #expect(restored.preferences == prefs)
        #expect(restored.themes == [customTheme()])
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(root.keys) == ["format", "version", "preferences", "themes"])
        let value = try #require(root["preferences"] as? [String: Any])
        let receiver = try #require((value["receivers"] as? [[String: Any]])?.first)
        #expect(Set(receiver.keys) == ["id", "name", "address", "username", "streamPort"])
        #expect(root["credentials"] == nil)
        #expect(root["reminders"] == nil)
    }

    @Test(arguments: ["format", "version", "schema", "address", "theme", "references"])
    func rejectsMalformedOrUnsupportedArchives(_ defect: String) throws {
        let data = try SettingsArchive(preferences: fixture(), themes: [customTheme()]).encoded()
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var prefs = try #require(root["preferences"] as? [String: Any])
        switch defect {
        case "format": root["format"] = "other-app"
        case "version": root["version"] = 99
        case "schema": prefs["schemaVersion"] = 99
        case "address":
            var profiles = try #require(prefs["receivers"] as? [[String: Any]])
            profiles[0]["address"] = "http://viewer:synthetic-secret@receiver.example"
            prefs["receivers"] = profiles
        case "references": prefs["selectedReceiverID"] = UUID().uuidString
        default:
            var themes = try #require(root["themes"] as? [[String: Any]])
            themes[0]["id"] = "../invalid"; root["themes"] = themes
        }
        root["preferences"] = prefs
        let corrupt = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: AtlasFailure.self) { try SettingsArchive.decode(corrupt) }
    }

    @Test func rejectsOversizeAndNonJSONData() {
        #expect(throws: AtlasFailure.self) { try SettingsArchive.decode(Data(repeating: 32, count: SettingsArchive.maximumBytes + 1)) }
        #expect(throws: AtlasFailure.self) { try SettingsArchive.decode(Data("not json".utf8)) }
    }

    @Test func reusesOnlyMatchingConnectionsAndRemapsImportedReferences() throws {
        let original = try fixture()
        var imported = original
        imported.receivers[0].id = UUID()
        imported.receivers[0].address = "http://RECEIVER.example:80/"
        let sourceID = imported.receivers[0].id
        imported.selectedReceiverID = sourceID
        imported.favoriteChannels = [FavoriteChannel(receiverID: sourceID, channel: Channel(id: "new", name: "New channel"))]
        imported.multiviewPresets?[0].receiverID = sourceID
        imported.appearance = .light
        let plan = try SettingsImportPlan(archive: SettingsArchive(preferences: imported, themes: []), current: original, existingThemes: [.system])
        #expect(plan.addedReceiverCount == 0)
        #expect(plan.preferences.receivers == original.receivers)
        #expect(plan.preferences.selectedReceiverID == original.selectedReceiverID)
        #expect(plan.preferences.favoriteChannels?.count == 2)
        #expect(plan.preferences.favoriteChannels?.allSatisfy { $0.receiverID == original.receivers[0].id } == true)
        #expect(plan.addedPresetCount == 0)
        #expect(plan.preferences.appearance == .light)
    }

    @Test(arguments: ["host", "scheme", "port", "user", "stream"])
    func changedConnectionNeverReusesImportedIDOrExistingCredentialIdentity(_ change: String) throws {
        let original = try fixture()
        var imported = original
        switch change {
        case "host": imported.receivers[0].address = "different.example"
        case "scheme": imported.receivers[0].address = "https://receiver.example"
        case "port": imported.receivers[0].address = "http://receiver.example:8080"
        case "user": imported.receivers[0].username = "different"
        default: imported.receivers[0].streamPort = 8002
        }
        let plan = try SettingsImportPlan(archive: SettingsArchive(preferences: imported, themes: []), current: original, existingThemes: [.system])
        #expect(plan.addedReceiverCount == 1)
        let added = try #require(plan.preferences.receivers.last)
        #expect(added.id != original.receivers[0].id)
        #expect(plan.preferences.selectedReceiverID == added.id)
        #expect(plan.preferences.favoriteChannels?.contains { $0.receiverID == added.id } == true)
        #expect(plan.preferences.multiviewPresets?.last?.receiverID == added.id)
        #expect(plan.preferences.receivers.first == original.receivers[0])
    }

    @Test func enforcesReceiverLimitWithoutDiscardingExistingProfiles() throws {
        var current = try fixture()
        try current.upsert(ReceiverProfile(name: "Second", address: "second.example"))
        try current.upsert(ReceiverProfile(name: "Third", address: "third.example"))
        var imported = try fixture(); imported.receivers[0].address = "fourth.example"
        let archive = try SettingsArchive(preferences: imported, themes: [])
        #expect(throws: AtlasFailure.self) { try SettingsImportPlan(archive: archive, current: current, existingThemes: [.system]) }
        #expect(current.receivers.count == 3)
    }

    @Test func preservesIdenticalConnectionAliasesAndNormalizesHTTPSPort() throws {
        var current = try fixture()
        let alias = ReceiverProfile(name: "Another name", address: current.receivers[0].address, username: current.receivers[0].username)
        try current.upsert(alias); current.selectedReceiverID = alias.id
        current.toggleFavorite(Channel(id: "alias-service", name: "Alias channel"), receiverID: alias.id)
        let plan = try SettingsImportPlan(archive: SettingsArchive(preferences: current, themes: []), current: current, existingThemes: [.system])
        #expect(plan.preferences.receivers == current.receivers)
        #expect(plan.preferences.selectedReceiverID == alias.id)
        #expect(plan.preferences.favoriteChannels == current.favoriteChannels)
        #expect(plan.addedFavoriteCount == 0)
        #expect(plan.addedPresetCount == 0)

        var secure = try fixture(); secure.receivers[0].address = "HTTPS://receiver.example"
        var incoming = secure; incoming.receivers[0].address = "https://receiver.example:443/"
        let equivalent = try SettingsImportPlan(archive: SettingsArchive(preferences: incoming, themes: []), current: secure, existingThemes: [.system])
        #expect(equivalent.addedReceiverCount == 0)
        incoming.receivers[0].address = "https://receiver.example:80/"
        let differentPort = try SettingsImportPlan(archive: SettingsArchive(preferences: incoming, themes: []), current: secure, existingThemes: [.system])
        #expect(differentPort.addedReceiverCount == 1)
    }

    @Test func conflictsKeepExistingThemesAndRepeatedImportsAreIdempotent() throws {
        var prefs = try fixture(); let incoming = customTheme(); prefs.themeID = incoming.id
        var existing = incoming; existing.name = "Existing theme"
        let archive = try SettingsArchive(preferences: prefs, themes: [incoming])
        let plan = try SettingsImportPlan(archive: archive, current: prefs, existingThemes: [.system, existing])
        let added = try #require(plan.themesToAdd.first)
        #expect(added.id != existing.id)
        #expect(plan.preferences.themeID == added.id)
        #expect(plan.originalThemes == [.system, existing])
        let repeated = try SettingsImportPlan(archive: archive, current: plan.preferences, existingThemes: [.system, existing, added])
        #expect(repeated.themesToAdd.isEmpty)
        #expect(repeated.addedReceiverCount == 0)
        #expect(repeated.addedFavoriteCount == 0)
        #expect(repeated.addedPresetCount == 0)
        #expect(repeated.preferences.themeID == added.id)
    }

    @Test func writesToChosenChannelAndRollsBackAddedThemesOnSettingsFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("e2Atlas-settings-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appendingPathComponent("channel/settings.json")
        let themes = directory.appendingPathComponent("channel/Themes")
        let prefs = try fixture()
        let archive = try SettingsArchive(preferences: prefs, themes: [customTheme()])
        let plan = try SettingsImportPlan(archive: archive, current: prefs, existingThemes: [.system])
        try plan.install(settingsURL: settings, themeDirectory: themes)
        #expect(try PreferencesStore(fileURL: settings).load() == plan.preferences)
        let themeFiles = try FileManager.default.contentsOfDirectory(at: themes, includingPropertiesForKeys: nil)
        #expect(themeFiles.count == 1)
        #expect(try AtlasTheme.decode(Data(contentsOf: #require(themeFiles.first))) == customTheme())
        let oldSettings = try Data(contentsOf: settings)
        let blockedDestination = directory.appendingPathComponent("blocked", isDirectory: true)
        try FileManager.default.createDirectory(at: blockedDestination, withIntermediateDirectories: true)
        #expect(throws: AtlasFailure.self) { try plan.install(settingsURL: blockedDestination, themeDirectory: themes) }
        #expect(try FileManager.default.contentsOfDirectory(at: themes, includingPropertiesForKeys: nil) == themeFiles)
        #expect(try Data(contentsOf: settings) == oldSettings)
    }
}
#endif
