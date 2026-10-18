import Foundation
import Observation
import AtlasCore

@MainActor @Observable
final class SettingsStore {
    var preferences: AppPreferences
    private(set) var error: String?
    private(set) var connectionRevision = 0
    let paths: AppPaths?
    let credentials = CredentialStore()
    @ObservationIgnored private let storage: PreferencesStore?
    @ObservationIgnored private var canSave = true

    init() {
        let paths = try? AppPaths()
        self.paths = paths
        storage = paths.map { PreferencesStore(fileURL: $0.support.appendingPathComponent("settings.json")) }
        do { preferences = try storage?.load() ?? AppPreferences() }
        catch { preferences = AppPreferences(); self.error = error.localizedDescription; canSave = false }
        updateNativeLanguagePreference()
    }
    var selectedReceiver: ReceiverProfile? { preferences.receivers.first { $0.id == preferences.selectedReceiverID } ?? preferences.receivers.first }
    var language: AppLanguage { preferences.language ?? .system }
    func setLanguage(_ language: AppLanguage) {
        preferences.language = language
        persist()
        if error == nil { updateNativeLanguagePreference() }
    }
    private func updateNativeLanguagePreference() {
        if language == .system { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages") }
    }
    func persist() {
        guard canSave, let storage else { error = error ?? "Die Einstellungen können nicht gespeichert werden."; return }
        do { try storage.save(preferences); error = nil } catch { self.error = error.localizedDescription }
    }
    func saveReceiver(_ profile: ReceiverProfile, password: String) throws {
        guard canSave, let storage else { throw AtlasFailure.storage(error ?? "Die Einstellungen sind nicht verfügbar.") }
        var updated = preferences
        try updated.upsert(profile)
        let oldPassword = try credentials.password(for: profile.id)
        try credentials.save(password, for: profile.id)
        do { try storage.save(updated) }
        catch {
            if preferences.receivers.contains(where: { $0.id == profile.id }) { try? credentials.save(oldPassword, for: profile.id) }
            else { try? credentials.remove(for: profile.id) }
            throw error
        }
        preferences = updated
        connectionRevision += 1
    }
    func removeReceiver(_ id: UUID) throws {
        guard canSave, let storage else { throw AtlasFailure.storage("Die Einstellungen sind nicht verfügbar.") }
        var updated = preferences; updated.removeReceiver(id: id)
        try storage.save(updated)
        preferences = updated
        do { try credentials.remove(for: id) } catch { self.error = error.localizedDescription }
    }
}
