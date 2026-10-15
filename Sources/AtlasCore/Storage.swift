import Foundation
import Security
import LocalAuthentication

public struct AppPaths: Sendable {
    public let support: URL
    public let cache: URL
    public init(fileManager: FileManager = .default, applicationID: String = Bundle.main.bundleIdentifier ?? "io.github.schrotty74.e2atlas.dev") throws {
        guard let supportBase = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let cacheBase = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw AtlasFailure.storage("Die macOS-Datenverzeichnisse sind nicht verfügbar.")
        }
        support = supportBase.appendingPathComponent(applicationID, isDirectory: true)
        cache = cacheBase.appendingPathComponent(applicationID, isDirectory: true)
    }
}

public struct PreferencesStore: Sendable {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }
    public func load() throws -> AppPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return AppPreferences() }
        do {
            let value = try JSONDecoder().decode(AppPreferences.self, from: Data(contentsOf: fileURL))
            try validate(value)
            return value
        } catch { throw AtlasFailure.storage("Die gespeicherten Einstellungen konnten nicht gelesen werden. Die Datei bleibt erhalten.") }
    }
    public func save(_ preferences: AppPreferences) throws {
        do {
            try validate(preferences)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: fileURL, options: .atomic)
        } catch { throw AtlasFailure.storage("Die Einstellungen konnten nicht gespeichert werden.") }
    }
    private func validate(_ value: AppPreferences) throws {
        guard value.schemaVersion == 1, value.receivers.count <= 3,
              Set(value.receivers.map(\.id)).count == value.receivers.count,
              value.receivers.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.address.isEmpty && (1...65535).contains($0.streamPort) }),
              value.selectedReceiverID == nil || value.receivers.contains(where: { $0.id == value.selectedReceiverID }),
              value.shortcuts.allSatisfy({ (0...23).contains($0.hour) && (0...59).contains($0.minute) }) else { throw AtlasFailure.invalidResponse }
    }
}

// A main-actor boundary keeps cache updates and synchronous Keychain operations
// ordered. The cache exists only in this process, never in the settings file.
@MainActor
public final class CredentialStore {
    private let backend: any CredentialBackend
    private var passwords: [UUID: String] = [:]

    public init(service: String = Bundle.main.bundleIdentifier ?? "io.github.schrotty74.e2atlas.dev") {
        backend = KeychainCredentialBackend(service: service)
    }

    init(backend: any CredentialBackend) { self.backend = backend }

    public func password(for id: UUID) throws -> String {
        if let password = passwords[id] { return password }
        let password = try backend.password(for: id)
        passwords[id] = password
        return password
    }

    public func save(_ password: String, for id: UUID) throws {
        // Editing a receiver name must not rewrite an unchanged password.
        if passwords[id] == password { return }
        try backend.save(password, for: id)
        passwords[id] = password
    }

    public func remove(for id: UUID) throws {
        try backend.remove(for: id)
        passwords.removeValue(forKey: id)
    }
}

@MainActor
protocol CredentialBackend {
    func password(for id: UUID) throws -> String
    func save(_ password: String, for id: UUID) throws
    func remove(for id: UUID) throws
}

@MainActor
private struct KeychainCredentialBackend: CredentialBackend {
    let service: String

    private func query(_ id: UUID) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: id.uuidString,
                kSecUseAuthenticationContext as String: context]
    }

    func password(for id: UUID) throws -> String {
        var request = query(id)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw failure(status, fallback: "Das Passwort konnte nicht aus dem Schlüsselbund gelesen werden.")
        }
        return password
    }

    func save(_ password: String, for id: UUID) throws {
        let request = query(id), values = [kSecValueData as String: Data(password.utf8)]
        let update = SecItemUpdate(request as CFDictionary, values as CFDictionary)
        if update == errSecItemNotFound {
            var item = request
            item[kSecValueData as String] = Data(password.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw failure(status, fallback: "Das Passwort konnte nicht sicher gespeichert werden.")
            }
        } else if update != errSecSuccess {
            throw failure(update, fallback: "Das Passwort konnte nicht sicher aktualisiert werden.")
        }
    }

    func remove(for id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw failure(status, fallback: "Das Passwort konnte nicht aus dem Schlüsselbund entfernt werden.")
        }
    }

    private func failure(_ status: OSStatus, fallback: String) -> AtlasFailure {
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed || status == errSecUserCanceled {
            return .storage("macOS hat den Schlüsselbund-Zugriff für diesen App-Build nicht freigegeben. Das gespeicherte Passwort bleibt erhalten.")
        }
        return .storage(fallback)
    }
}
