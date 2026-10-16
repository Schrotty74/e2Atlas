import Foundation
import Testing
@testable import AtlasCore

@Suite("App preference behavior")
struct AppPreferencesTests {
    @Test func developmentIdentityReusesOnlyItsLegacyStorageIdentifier() throws {
        #expect(AppIdentity.developmentBundleIdentifier == "io.github.schrotty74.e2atlas.development")
        #expect(AppIdentity.legacyDevelopmentIdentifier == "io.github.schrotty74.e2atlas.dev")
        #expect(AppIdentity.storageIdentifier(for: AppIdentity.developmentBundleIdentifier) == AppIdentity.legacyDevelopmentIdentifier)
        #expect(AppIdentity.storageIdentifier(for: AppIdentity.legacyDevelopmentIdentifier) == AppIdentity.legacyDevelopmentIdentifier)
        #expect(AppIdentity.storageIdentifier(for: "io.github.schrotty74.e2atlas.beta") == "io.github.schrotty74.e2atlas.beta")
        #expect(AppIdentity.storageIdentifier(for: "io.github.schrotty74.e2atlas") == "io.github.schrotty74.e2atlas")
        #expect(AppIdentity.storageIdentifier(for: "example.custom.app") == "example.custom.app")
    }

    @Test func newDevelopmentIdentityUsesExistingSupportAndCacheLocations() throws {
        let developmentPaths = try AppPaths(applicationID: AppIdentity.developmentBundleIdentifier)
        let legacyPaths = try AppPaths(applicationID: AppIdentity.legacyDevelopmentIdentifier)

        #expect(developmentPaths.support == legacyPaths.support)
        #expect(developmentPaths.cache == legacyPaths.cache)
        #expect(developmentPaths.support.lastPathComponent == AppIdentity.legacyDevelopmentIdentifier)
        #expect(developmentPaths.cache.lastPathComponent == AppIdentity.legacyDevelopmentIdentifier)
    }

    @Test func allowsThreeReceiversAndRejectsAFourth() throws {
        var preferences = AppPreferences()
        let profiles = (1...3).map { index in
            ReceiverProfile(name: "Receiver \(index)", address: "box\(index).example")
        }

        for profile in profiles { try preferences.upsert(profile) }
        #expect(preferences.receivers.count == 3)
        #expect(preferences.selectedReceiverID == profiles[0].id)

        do {
            try preferences.upsert(ReceiverProfile(name: "Fourth", address: "box4.example"))
            Issue.record("The fourth receiver should be rejected")
        } catch let failure as AtlasFailure {
            guard case .storage = failure else {
                Issue.record("Expected a storage validation error")
                return
            }
        }
        #expect(preferences.receivers.count == 3)
    }

    @Test func updatesAnExistingReceiverAtTheLimit() throws {
        var preferences = AppPreferences()
        let profiles = (1...3).map { index in
            ReceiverProfile(name: "Receiver \(index)", address: "box\(index).example")
        }
        for profile in profiles { try preferences.upsert(profile) }

        var changed = profiles[1]
        changed.name = "Updated receiver"
        changed.address = "updated.example"
        try preferences.upsert(changed)

        #expect(preferences.receivers.count == 3)
        #expect(preferences.receivers[1] == changed)
    }

    @Test func rejectsBlankReceiverNames() {
        var preferences = AppPreferences()
        #expect(throws: AtlasFailure.self) {
            try preferences.upsert(ReceiverProfile(name: " \n ", address: "box.example"))
        }
        #expect(preferences.receivers.isEmpty)
    }

    @Test func roundTripsSettingsWithoutPasswordFields() throws {
        let fileURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = PreferencesStore(fileURL: fileURL)
        var original = AppPreferences()
        let first = ReceiverProfile(name: "Living room", address: "receiver.local", username: "viewer")
        let second = ReceiverProfile(name: "Bedroom", address: "192.0.2.20", username: "guest", streamPort: 8002)
        try original.upsert(first)
        try original.upsert(second)
        original.appearance = .dark
        original.themeID = "ocean"
        original.guideDuration = .four
        original.addShortcut(try TimeShortcut(hour: 19, minute: 30))

        try store.save(original)
        let restored = try store.load()
        #expect(restored == original)
        let savedText = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(savedText.localizedCaseInsensitiveContains("password") == false)
    }

    @Test func rejectsInvalidSaveWithoutReplacingExistingValidFile() throws {
        let fileURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = PreferencesStore(fileURL: fileURL)
        var valid = AppPreferences()
        let profiles = (1...3).map { index in
            ReceiverProfile(name: "Receiver \(index)", address: "box\(index).example")
        }
        for profile in profiles { try valid.upsert(profile) }
        try store.save(valid)
        let originalBytes = try Data(contentsOf: fileURL)

        var invalid = valid
        invalid.receivers.append(ReceiverProfile(name: "Fourth", address: "box4.example"))
        #expect(throws: AtlasFailure.self) {
            try store.save(invalid)
        }

        #expect(try Data(contentsOf: fileURL) == originalBytes)
        #expect(try store.load() == valid)
    }

    @Test func missingSettingsUseDefaultsIncludingEveningShortcut() throws {
        let fileURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let loaded = try PreferencesStore(fileURL: fileURL).load()
        #expect(loaded == AppPreferences())
        #expect(loaded.shortcuts.map(\.id) == ["20:15"])
        #expect(loaded.appearance == .automatic)
        #expect(loaded.guideDuration == .two)
    }

    @Test(arguments: ["not-json", "unsupported-schema", "too-many-receivers", "invalid-shortcut"])
    func preservesUnreadableSettingsFile(fixture: String) throws {
        let fileURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let data = try corruptFixture(named: fixture)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)

        do {
            _ = try PreferencesStore(fileURL: fileURL).load()
            Issue.record("Corrupt or unsupported settings should fail to load")
        } catch let failure as AtlasFailure {
            guard case .storage(let message) = failure else {
                Issue.record("Expected a storage error")
                return
            }
            #expect(message.contains("Die Datei bleibt erhalten"))
        }
        #expect(try Data(contentsOf: fileURL) == data)
    }

    @Test func rejectsInvalidShortcutTimeValues() {
        #expect(throws: AtlasFailure.self) { try TimeShortcut(hour: -1, minute: 0) }
        #expect(throws: AtlasFailure.self) { try TimeShortcut(hour: 24, minute: 0) }
        #expect(throws: AtlasFailure.self) { try TimeShortcut(hour: 12, minute: 60) }
    }

    @Test func sortsAndDeduplicatesShortcuts() throws {
        var preferences = AppPreferences()
        preferences.addShortcut(try TimeShortcut(hour: 7, minute: 45))
        preferences.addShortcut(try TimeShortcut(hour: 19, minute: 30))
        preferences.addShortcut(try TimeShortcut(hour: 7, minute: 45))

        #expect(preferences.shortcuts.map(\.id) == ["07:45", "19:30", "20:15"])
    }

    @Test func resolvesShortcutOnRequestedCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15)))
        let shortcut = try TimeShortcut(hour: 20, minute: 15)
        let date = try #require(shortcut.date(on: day, calendar: calendar))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 10)
        #expect(components.day == 15)
        #expect(components.hour == 20)
        #expect(components.minute == 15)
    }

    @Test func clipsProgrammesAtGuideWindowEdges() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let window = GuideWindow(start: start, duration: .two)
        let partlyBefore = programme(start: start.addingTimeInterval(-1_800), end: start.addingTimeInterval(1_800))
        let fullyInside = programme(start: start.addingTimeInterval(1_800), end: start.addingTimeInterval(5_400))
        let partlyAfter = programme(start: start.addingTimeInterval(6_600), end: start.addingTimeInterval(9_000))
        let outside = programme(start: start.addingTimeInterval(-7_200), end: start)

        let beforeFraction = try #require(window.visibleFraction(of: partlyBefore))
        #expect(beforeFraction.offset == 0)
        #expect(beforeFraction.width == 0.25)
        let insideFraction = try #require(window.visibleFraction(of: fullyInside))
        #expect(insideFraction.offset == 0.25)
        #expect(insideFraction.width == 0.5)
        let afterFraction = try #require(window.visibleFraction(of: partlyAfter))
        #expect(afterFraction.offset == 0.9166666666666666)
        #expect(afterFraction.width == 0.08333333333333333)
        #expect(window.visibleFraction(of: outside) == nil)
    }

    @Test(arguments: [GuideDuration.two, .four, .six])
    func guideDurationMapsToHours(_ duration: GuideDuration) {
        #expect(duration.seconds == Double(duration.rawValue * 3_600))
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("e2Atlas-CoreTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("preferences.json")
    }

    private func programme(start: Date, end: Date) -> Programme {
        Programme(id: UUID().uuidString, channelID: "service", title: "Program", summary: "", start: start, end: end)
    }

    private func corruptFixture(named name: String) throws -> Data {
        switch name {
        case "not-json": return Data("{not json".utf8)
        case "unsupported-schema", "invalid-shortcut":
            guard var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppPreferences())) as? [String: Any] else {
                throw AtlasFailure.invalidResponse
            }
            if name == "unsupported-schema" {
                value["schemaVersion"] = 2
            } else {
                value["shortcuts"] = [["hour": 27, "minute": 0]]
            }
            return try JSONSerialization.data(withJSONObject: value)
        default:
            var preferences = AppPreferences()
            for index in 1...3 {
                try preferences.upsert(ReceiverProfile(name: "Box \(index)", address: "box\(index).example"))
            }
            guard var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any],
                  var receivers = value["receivers"] as? [[String: Any]] else {
                throw AtlasFailure.invalidResponse
            }
            receivers.append(["id": UUID().uuidString, "name": "Box 4", "address": "box4.example", "username": "", "streamPort": 8001])
            value["receivers"] = receivers
            return try JSONSerialization.data(withJSONObject: value)
        }
    }
}

extension AppPreferencesTests {
    @Test func sixHourWindowCrossesMidnightWithoutWrappingEvents() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 20, minute: 15)))
        let window = GuideWindow(start: start, duration: .six)
        #expect(calendar.component(.day, from: window.end) == 16)
        #expect(calendar.component(.hour, from: window.end) == 2)
        let afterMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 0, minute: 15)))
        let event = Programme(id: "overnight", channelID: "synthetic", title: "After midnight", summary: "", start: afterMidnight, end: afterMidnight.addingTimeInterval(3600))
        let position = try #require(window.visibleFraction(of: event))
        #expect(abs(position.offset - 4.0 / 6.0) < 0.0001)
        #expect(abs(position.width - 1.0 / 6.0) < 0.0001)
    }
}


@Suite("Credentials in the current app session")
@MainActor
struct CredentialSessionTests {
    @Test func repeatedReadsUseMemoryAndKeepReceiversSeparate() throws {
        let backend = MemoryCredentialBackend()
        let first = UUID(), second = UUID()
        backend.values = [first: "synthetic-first", second: "synthetic-second"]
        let store = CredentialStore(backend: backend)
        #expect(try store.password(for: first) == "synthetic-first")
        #expect(try store.password(for: first) == "synthetic-first")
        #expect(try store.password(for: second) == "synthetic-second")
        #expect(backend.reads == 2)
    }

    @Test func unchangedPasswordIsNotWrittenAgain() throws {
        let backend = MemoryCredentialBackend()
        let id = UUID()
        backend.values[id] = "synthetic"
        let store = CredentialStore(backend: backend)
        _ = try store.password(for: id)
        try store.save("synthetic", for: id)
        #expect(backend.writes == 0)
        try store.save("changed-synthetic", for: id)
        #expect(backend.writes == 1)
        #expect(try store.password(for: id) == "changed-synthetic")
        #expect(backend.reads == 1)
    }

    @Test func automaticFallbackPreservesSecretAndCanRecover() throws {
        let backend = MemoryCredentialBackend()
        let id = UUID()
        backend.values[id] = "synthetic"
        backend.interactionRequired = true
        let store = CredentialStore(backend: backend)
        #expect(try store.availablePassword(for: id) == "")
        #expect(backend.values[id] == "synthetic")
        #expect(backend.writes == 0)
        backend.interactionRequired = false
        #expect(try store.availablePassword(for: id) == "synthetic")
    }

    @Test func automaticFallbackDoesNotHideOtherStorageErrors() throws {
        let backend = MemoryCredentialBackend()
        backend.reject = true
        let store = CredentialStore(backend: backend)
        #expect(throws: AtlasFailure.self) { try store.availablePassword(for: UUID()) }
    }

    @Test func rejectedAccessPreservesTheStoredSecret() throws {
        let backend = MemoryCredentialBackend()
        let id = UUID()
        backend.values[id] = "synthetic"
        let store = CredentialStore(backend: backend)
        backend.reject = true
        #expect(throws: AtlasFailure.self) { try store.password(for: id) }
        #expect(throws: AtlasFailure.self) { try store.save("replacement", for: id) }
        #expect(backend.values[id] == "synthetic")
        backend.reject = false
        #expect(try store.password(for: id) == "synthetic")
        try store.remove(for: id)
        #expect(try store.password(for: id) == "")
        #expect(backend.values[id] == nil)
    }
}

@MainActor
private final class MemoryCredentialBackend: CredentialBackend {
    var values: [UUID: String] = [:]
    var reads = 0
    var writes = 0
    var reject = false
    var interactionRequired = false
    func password(for id: UUID) throws -> String {
        reads += 1
        if interactionRequired { throw AtlasFailure.credentialsUnavailable }
        if reject { throw AtlasFailure.storage("Synthetic access refusal") }
        return values[id] ?? ""
    }
    func save(_ password: String, for id: UUID) throws {
        if reject { throw AtlasFailure.storage("Synthetic access refusal") }
        writes += 1
        values[id] = password
    }
    func remove(for id: UUID) throws {
        if reject { throw AtlasFailure.storage("Synthetic access refusal") }
        values.removeValue(forKey: id)
    }
}
