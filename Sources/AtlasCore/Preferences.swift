import Foundation

public enum Appearance: String, Codable, CaseIterable, Sendable {
    case automatic, light, dark
    public var title: String { switch self { case .automatic: "Automatisch"; case .light: "Hell"; case .dark: "Dunkel" } }
}

public enum GuideDuration: Int, Codable, CaseIterable, Sendable {
    case two = 2, four = 4, six = 6
    public var seconds: TimeInterval { Double(rawValue) * 3600 }
}

public struct TimeShortcut: Codable, Identifiable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int
    public var id: String { String(format: "%02d:%02d", hour, minute) }
    public init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw AtlasFailure.invalidResponse }
        self.hour = hour; self.minute = minute
    }
    public func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

public struct AppPreferences: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var receivers: [ReceiverProfile] = []
    public var selectedReceiverID: UUID?
    public var appearance: Appearance = .automatic
    public var themeID = "system"
    public var guideDuration: GuideDuration = .two
    public var shortcuts: [TimeShortcut] = []
    public var multiviewPresets: [MultiviewPreset]?
    public var language: AppLanguage?
    public var autoConnectOnLaunch: Bool?
    public var connectsOnLaunch: Bool { autoConnectOnLaunch ?? true }
    public init() {
        if let evening = try? TimeShortcut(hour: 20, minute: 15) { shortcuts = [evening] }
    }
    public mutating func upsert(_ profile: ReceiverProfile) throws {
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AtlasFailure.storage("Bitte einen Namen für den Receiver eingeben.")
        }
        if let index = receivers.firstIndex(where: { $0.id == profile.id }) { receivers[index] = profile }
        else {
            guard receivers.count < 3 else { throw AtlasFailure.storage("Es können höchstens drei Receiver eingerichtet werden.") }
            receivers.append(profile)
        }
        if selectedReceiverID == nil { selectedReceiverID = profile.id }
    }
    public mutating func removeReceiver(id: UUID) {
        receivers.removeAll { $0.id == id }
        multiviewPresets?.removeAll { $0.receiverID == id }
        if selectedReceiverID == id { selectedReceiverID = receivers.first?.id }
    }
    public mutating func addShortcut(_ value: TimeShortcut) {
        if !shortcuts.contains(value) { shortcuts.append(value); shortcuts.sort { $0.id < $1.id } }
    }
}

public struct GuideWindow: Sendable, Equatable {
    public var start: Date
    public var duration: GuideDuration
    public var end: Date { start.addingTimeInterval(duration.seconds) }
    public init(start: Date, duration: GuideDuration) { self.start = start; self.duration = duration }
    public func visibleFraction(of programme: Programme) -> (offset: Double, width: Double)? {
        let lower = max(start, programme.start), upper = min(end, programme.end)
        guard upper > lower else { return nil }
        return (lower.timeIntervalSince(start) / duration.seconds, upper.timeIntervalSince(lower) / duration.seconds)
    }
}
