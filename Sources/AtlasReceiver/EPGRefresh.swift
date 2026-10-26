import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum EPGRefreshFailure: Error, LocalizedError, Sendable {
    case unavailable, unsupported, clockUnavailable, invalidPlan, changed, incomplete
    public var errorDescription: String? {
        switch self {
        case .unavailable: "EPGRefresh ist auf diesem Receiver nicht über OpenWebif verfügbar. Installiere oder aktiviere das Plugin am Receiver."
        case .unsupported: "Die EPGRefresh-Schnittstelle dieses Receivers wird nicht unterstützt. Es wurde nichts geändert."
        case .clockUnavailable: "Die Receiver-Uhrzeit konnte nicht zuverlässig zugeordnet werden. Bitte Uhrzeit und Zeitzone prüfen. Es wurde nichts geändert."
        case .invalidPlan: "Bitte ein gültiges Zeitfenster, eine Verweildauer und mindestens ein Bouquet wählen."
        case .changed: "Die EPGRefresh-Einstellungen wurden zwischenzeitlich geändert. Bitte neu laden."
        case .incomplete: "Der EPG-Zeitplan konnte nicht vollständig gespeichert werden. Bitte die Einstellungen am Receiver neu laden und prüfen."
        }
    }
}

public struct EPGRefreshConfiguration: Sendable, Equatable {
    public var enabled: Bool
    public var begin: Date
    public var end: Date
    public var durationSeconds: Int
    public let references: [String]
    public let receiverUTCOffset: Int
    let force: Bool
    let inheritsAutoTimer: Bool
    public var receiverTimeZone: TimeZone { TimeZone(secondsFromGMT: receiverUTCOffset) ?? TimeZone(secondsFromGMT: 0)! }

    static func decode(settings data: Data, services: Data, clock: String, now: Date) throws -> Self {
        let values = try EPGRefreshXML.read(data, root: "e2settings").settings
        let list = try EPGRefreshXML.read(services, root: "epgrefresh")
        guard list.version == "1", values["api_version"] != nil,
              let enabled = flag(values["config.plugins.epgrefresh.enabled"]),
              let begin = epoch(values["config.plugins.epgrefresh.begin"]),
              let end = epoch(values["config.plugins.epgrefresh.end"]),
              let duration = values["config.plugins.epgrefresh.interval_seconds"].flatMap(Int.init),
              (1...86400).contains(duration),
              let force = flag(values["config.plugins.epgrefresh.force"]),
              let inherits = flag(values["config.plugins.epgrefresh.inherit_autotimer"]) else {
            throw EPGRefreshFailure.unsupported
        }
        let offset = try clockOffset(clock, now: now)
        return Self(enabled: enabled, begin: begin, end: end, durationSeconds: duration,
                    references: list.references.sorted(), receiverUTCOffset: offset,
                    force: force, inheritsAutoTimer: inherits)
    }

    // Only the wall-clock minute matters: the receiver discards the supplied date.
    func minute(_ date: Date) -> Int {
        let minutes = Int(floor((date.timeIntervalSince1970 + Double(receiverUTCOffset)) / 60))
        return ((minutes % 1440) + 1440) % 1440
    }

    func matches(_ other: Self) -> Bool {
        enabled == other.enabled && minute(begin) == other.minute(other.begin)
            && minute(end) == other.minute(other.end) && durationSeconds == other.durationSeconds
            && references == other.references && force == other.force && inheritsAutoTimer == other.inheritsAutoTimer
    }

    static func clockOffset(_ clock: String, now: Date) throws -> Int {
        let fields = clock.split(separator: ":", omittingEmptySubsequences: false)
        let parts = fields.compactMap { Int($0) }
        guard fields.count == 3, parts.count == 3, (0...23).contains(parts[0]), (0...59).contains(parts[1]), (0...59).contains(parts[2]),
              now.timeIntervalSince1970.isFinite else { throw EPGRefreshFailure.clockUnavailable }
        let local = parts[0] * 3600 + parts[1] * 60 + parts[2]
        let utc = Int(now.timeIntervalSince1970) % 86400
        let difference = ((local - utc + 129600) % 86400) - 43200
        let offset = Int((Double(difference) / 900).rounded()) * 900
        guard abs(difference - offset) <= 30 else { throw EPGRefreshFailure.clockUnavailable }
        return offset
    }

    private static func flag(_ value: String?) -> Bool? {
        switch value?.lowercased() {
        case "true", "1": true
        case "false", "0": false
        default: nil
        }
    }
    private static func epoch(_ value: String?) -> Date? {
        guard let value, let number = Int64(value), (-62_135_596_800...253_402_300_799).contains(number) else { return nil }
        return Date(timeIntervalSince1970: Double(number))
    }
}

/// Small, bounded parser for the plugin's documented XML resources; never resolves external entities.
final class EPGRefreshXML: NSObject, XMLParserDelegate {
    private(set) var settings: [String: String] = [:]
    private(set) var references: [String] = []
    private(set) var version: String?
    private(set) var success: Bool?
    private var root: String?
    private var text = ""
    private var key: String?
    private var value: String?
    private var reference: String?

    static func read(_ data: Data, root: String) throws -> EPGRefreshXML {
        guard data.count <= 2_000_000 else { throw EPGRefreshFailure.unsupported }
        let delegate = EPGRefreshXML()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.root == root else { throw EPGRefreshFailure.unsupported }
        return delegate
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        if root == nil { root = elementName; version = attributes["version"] }
        if elementName == "e2setting" { key = nil; value = nil }
        if elementName == "e2service" { reference = nil }
        text = ""
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "e2settingname": key = trimmed
        case "e2settingvalue": value = trimmed
        case "e2setting": if let key, let value { settings[key] = value }
        case "e2servicereference": reference = trimmed
        case "e2service": if let reference, !reference.isEmpty { references.append(reference) }
        case "e2state": success = trimmed.lowercased() == "true" ? true : trimmed.lowercased() == "false" ? false : nil
        default: break
        }
    }
}
