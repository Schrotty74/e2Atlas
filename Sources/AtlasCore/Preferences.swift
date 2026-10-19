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
    public var favoriteChannels: [FavoriteChannel]?
    public var language: AppLanguage?
    public var autoConnectOnLaunch: Bool?
    public var connectsOnLaunch: Bool { autoConnectOnLaunch ?? true }
    public var epgDisplayRefreshMinutes: Int?
    public var epgUpdateIntervalMinutes: Int?
    public var epgRefreshStartDate: Date?
    public var epgRefreshMinutes: Int {
        // Preserve an explicit legacy Off choice; migrate the former short presets to six hours.
        guard let value = epgUpdateIntervalMinutes else { return epgDisplayRefreshMinutes == 0 ? 0 : 360 }
        guard (0...10080).contains(value) else { return 360 }
        return value
    }

    public func nextEPGRefresh(after date: Date, sessionStartedAt: Date) -> Date? {
        guard epgRefreshMinutes > 0 else { return nil }
        let interval = Double(epgRefreshMinutes) * 60
        let fallback = sessionStartedAt.addingTimeInterval(interval)
        let start = epgRefreshStartDate.flatMap { $0.timeIntervalSince1970.isFinite ? $0 : nil } ?? fallback
        if start > date { return start }
        let steps = floor(date.timeIntervalSince(start) / interval) + 1
        let next = start.addingTimeInterval(steps * interval)
        return next.timeIntervalSince1970.isFinite && next > date ? next : date.addingTimeInterval(interval)
    }
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
        favoriteChannels?.removeAll { $0.receiverID == id }
        if selectedReceiverID == id { selectedReceiverID = receivers.first?.id }
    }
    public func isFavorite(_ channel: Channel, receiverID: UUID) -> Bool {
        (favoriteChannels ?? []).contains { $0.receiverID == receiverID && $0.channel.id == channel.id }
    }
    public mutating func toggleFavorite(_ channel: Channel, receiverID: UUID) {
        guard receivers.contains(where: { $0.id == receiverID }), !channel.id.isEmpty else { return }
        if isFavorite(channel, receiverID: receiverID) { favoriteChannels?.removeAll { $0.receiverID == receiverID && $0.channel.id == channel.id } }
        else if (favoriteChannels ?? []).count < 300 {
            favoriteChannels = (favoriteChannels ?? []) + [FavoriteChannel(receiverID: receiverID, channel: channel)]
        }
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

/// The horizontal guide covers seven local calendar days, including clock changes.
public struct GuideTimelineRange: Sendable, Equatable {
    public let start: Date
    public let end: Date
    public var seconds: TimeInterval { end.timeIntervalSince(start) }

    public init(containing date: Date, calendar: Calendar = .current) {
        start = calendar.startOfDay(for: date)
        end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
    }

    public func boundedStart(_ date: Date, duration: GuideDuration) -> Date {
        min(max(date, start), end.addingTimeInterval(-duration.seconds))
    }

    public func fraction(of date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(start) / seconds))
    }

    public func visibleFraction(of programme: Programme) -> (offset: Double, width: Double)? {
        let lower = max(start, programme.start), upper = min(end, programme.end)
        guard upper > lower else { return nil }
        return (lower.timeIntervalSince(start) / seconds, upper.timeIntervalSince(lower) / seconds)
    }

    public func visibleStart(offset: Double, timelineWidth: Double, duration: GuideDuration) -> Date {
        guard offset.isFinite, timelineWidth.isFinite, timelineWidth > 0 else { return start }
        return boundedStart(start.addingTimeInterval(seconds * min(1, max(0, offset / timelineWidth))), duration: duration)
    }
}
