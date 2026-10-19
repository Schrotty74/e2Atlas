import Foundation

#if !arch(arm64)
#error("e2Atlas requires Apple Silicon.")
#endif

public struct ReceiverProfile: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var address: String
    public var username: String
    public var streamPort: Int
    public init(id: UUID = UUID(), name: String, address: String, username: String = "", streamPort: Int = 8001) {
        self.id = id; self.name = name; self.address = address; self.username = username; self.streamPort = streamPort
    }
}

public struct Channel: Codable, Identifiable, Sendable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var number: Int?
    public init(id: String, name: String, number: Int? = nil) { self.id = id; self.name = name; self.number = number }
}

public struct Bouquet: Codable, Identifiable, Sendable, Equatable, Hashable {
    public var id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct Programme: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var channelID: String
    public var title: String
    public var summary: String
    public var start: Date
    public var end: Date
    public init(id: String, channelID: String, title: String, summary: String, start: Date, end: Date) {
        self.id = id; self.channelID = channelID; self.title = title; self.summary = summary; self.start = start; self.end = end
    }
}

public struct ReceiverInfo: Sendable, Equatable {
    public var name: String
    public var image: String
    public init(name: String, image: String) { self.name = name; self.image = image }
}

public enum AtlasFailure: Error, LocalizedError, Sendable, Equatable {
    case invalidAddress, unauthorized, unreachable, invalidResponse, credentialsUnavailable
    case unsupported(String), storage(String)
    public var errorDescription: String? {
        switch self {
        case .invalidAddress: "Bitte eine gültige IP-Adresse oder einen Hostnamen eingeben."
        case .credentialsUnavailable: "Das gespeicherte Passwort ist für diesen App-Build ohne Schlüsselbund-Freigabe nicht verfügbar. Der Eintrag bleibt erhalten."
        case .unauthorized: "Die Anmeldung wurde abgelehnt. Bitte Benutzername und Passwort prüfen."
        case .unreachable: "Der Receiver ist nicht erreichbar. Bitte Adresse und Netzwerk prüfen."
        case .invalidResponse: "Die Antwort des Receivers konnte nicht gelesen werden."
        case .unsupported(let message), .storage(let message): message
        }
    }
}

/// A channel-local layout stores receiver references, never stream URLs or credentials.
public struct MultiviewPreset: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var receiverID: UUID
    public var channels: [Channel?]
    public var audibleIndex: Int
    public var volume: Double
    public var isMuted: Bool
    public init(id: UUID = UUID(), name: String, receiverID: UUID, channels: [Channel?], audibleIndex: Int, volume: Double, isMuted: Bool) {
        self.id = id; self.name = name; self.receiverID = receiverID; self.channels = channels
        self.audibleIndex = audibleIndex; self.volume = volume; self.isMuted = isMuted
    }
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
            && (2...4).contains(channels.count) && channels.indices.contains(audibleIndex)
            && volume.isFinite && (0...1).contains(volume)
            && channels.contains(where: { $0 != nil })
            && channels.compactMap { $0 }.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty }
    }
}

public extension Programme {
    func progress(at date: Date) -> Double {
        guard end > start else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }
    static func search(_ query: String, in events: [Programme]) -> [Programme] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return events.filter { query.isEmpty || $0.title.localizedStandardContains(query) || $0.summary.localizedStandardContains(query) }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
