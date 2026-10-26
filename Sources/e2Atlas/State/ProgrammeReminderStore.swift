import Foundation
import Observation
import UserNotifications
import AtlasCore

private final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let openReminder: @Sendable (String, ProgrammeReminder?) -> Void
    init(openReminder: @escaping @Sendable (String, ProgrammeReminder?) -> Void) { self.openReminder = openReminder }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        let encoded = info["programmeReminder"] as? String
        let reminder = encoded.flatMap { try? JSONDecoder().decode(ProgrammeReminder.self, from: Data($0.utf8)) }
        openReminder(identifier, reminder)
    }
}

@MainActor @Observable
final class ProgrammeReminderStore {
    private(set) var reminders: [ProgrammeReminder] = []
    private(set) var error: String?
    private(set) var isSaving = false
    private(set) var pendingOpen: ProgrammeReminder?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private var canSave = false
    @ObservationIgnored private var receiverIDs = Set<UUID>()
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private var delegate: ReminderNotificationDelegate?
    @ObservationIgnored private var knownTargets: [String: ProgrammeReminder] = [:]

    func configure(fileURL: URL?) {
        guard self.fileURL == nil, let fileURL else { return }
        self.fileURL = fileURL
        delegate = ReminderNotificationDelegate { [weak self] identifier, decoded in
            Task { @MainActor [weak self] in self?.receiveOpen(identifier: identifier, decoded: decoded) }
        }
        center.delegate = delegate
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                guard data.count <= 1_048_576 else { throw AtlasFailure.invalidResponse }
                let stored = try JSONDecoder().decode([ProgrammeReminder].self, from: data)
                guard stored.count <= 50, Set(stored.map(\.id)).count == stored.count else { throw AtlasFailure.invalidResponse }
                knownTargets = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
                reminders = stored.filter { $0.isValid(after: Date()) }.sorted { $0.fireDate < $1.fireDate }
            }
            canSave = true
        } catch { self.error = "Die gespeicherten Erinnerungen konnten nicht gelesen werden. Die Datei bleibt erhalten." }
    }

    func reminder(for event: Programme, receiverID: UUID?) -> ProgrammeReminder? {
        reminders.first { $0.receiverID == receiverID && $0.programme.id == event.id && $0.fireDate > Date() }
    }

    func add(event: Programme, channel: Channel, receiverID: UUID, minutes: Int, language: AppLanguage) async {
        guard !isSaving else { return }
        let value = ProgrammeReminder(receiverID: receiverID, programme: event, channelName: channel.name, minutesBefore: minutes)
        guard value.isValid(after: Date()) else { error = "Der Erinnerungszeitpunkt liegt bereits in der Vergangenheit."; return }
        guard canSave, let fileURL else { error = "Erinnerungen können derzeit nicht gespeichert werden."; return }
        let previous = reminders.first { $0.id == value.id }
        guard previous != nil || reminders.filter { $0.fireDate > Date() }.count < 50 else { error = "Es sind höchstens 50 Erinnerungen möglich."; return }
        isSaving = true; error = nil
        defer { isSaving = false; retainReceivers(receiverIDs) }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                error = "Mitteilungen sind nicht erlaubt. Bitte e2Atlas in den macOS-Mitteilungseinstellungen freigeben."; return
            }
            guard receiverIDs.contains(receiverID) else { return }
            guard value.isValid(after: Date()) else { error = "Der Erinnerungszeitpunkt liegt bereits in der Vergangenheit."; return }
            try await center.add(request(for: value, language: language))
            guard receiverIDs.contains(receiverID) else { center.removePendingNotificationRequests(withIdentifiers: [value.id]); return }
            let updated = (reminders.filter { $0.id != value.id && $0.fireDate > Date() } + [value]).sorted { $0.fireDate < $1.fireDate }
            do { try save(updated, to: fileURL); reminders = updated; knownTargets[value.id] = value }
            catch {
                center.removePendingNotificationRequests(withIdentifiers: [value.id])
                if let previous, previous.isValid(after: Date()) { try? await center.add(request(for: previous, language: language)) }
                throw error
            }
        } catch { self.error = "Die Erinnerung konnte nicht gespeichert werden. Bitte Mitteilungsfreigabe und Speicher prüfen." }
    }

    func remove(_ value: ProgrammeReminder) {
        guard !isSaving, canSave, let fileURL else { return }
        do {
            let updated = reminders.filter { $0.id != value.id }
            try save(updated, to: fileURL); reminders = updated; error = nil
            knownTargets.removeValue(forKey: value.id)
            center.removePendingNotificationRequests(withIdentifiers: [value.id])
            center.removeDeliveredNotifications(withIdentifiers: [value.id])
        } catch { self.error = "Die Erinnerung konnte nicht entfernt werden." }
    }

    func retainReceivers(_ ids: Set<UUID>) {
        receiverIDs = ids
        guard !isSaving else { return }
        for value in reminders where !ids.contains(value.receiverID) { remove(value) }
    }

    /// Reconcile only with a successful, fresh EPG result for this receiver.
    /// The caller supplies data it already loaded; this method performs no network access.
    func reconcile(receiverID: UUID, channels: [Channel], freshProgrammes: [Programme], language: AppLanguage) async {
        guard canSave, let fileURL, receiverIDs.contains(receiverID), !isSaving else { return }
        let channelByID = Dictionary(channels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let incomingByChannel = Dictionary(grouping: freshProgrammes, by: \.channelID)
        let current = reminders
        var replacements: [ProgrammeReminder] = []
        var cancellations = Set<String>()
        var retained: [ProgrammeReminder] = []
        let now = Date()
        for value in current where value.receiverID == receiverID {
            guard let channel = channelByID[value.programme.channelID], let feed = incomingByChannel[channel.id] else {
                retained.append(value); continue
            }
            let exact = feed.first(where: {
                $0.id == value.programme.id && $0.channelID == value.programme.channelID
                    && $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        .localizedCompare(value.programme.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            })
            let candidate = exact ?? ProgrammeReminderMatcher.match(value, in: feed)
            guard let candidate else { retained.append(value); continue }
            let updated = ProgrammeReminder(receiverID: receiverID, programme: candidate,
                                            channelName: channel.name, minutesBefore: value.minutesBefore)
            if updated.id != value.id { cancellations.insert(value.id) }
            guard updated.isValid(after: now) else { cancellations.insert(value.id); continue }
            if updated != value { cancellations.insert(value.id); replacements.append(updated) }
            else { retained.append(value) }
        }
        guard !cancellations.isEmpty || !replacements.isEmpty else { return }
        let updated = Array((retained + replacements + current.filter { $0.receiverID != receiverID })
            .reduce(into: [String: ProgrammeReminder]()) { $0[$1.id] = $1 }.values)
            .filter { $0.isValid(after: now) }.sorted { $0.fireDate < $1.fireDate }
        isSaving = true
        let previousTargets = knownTargets
        defer { isSaving = false; retainReceivers(receiverIDs) }
        do {
            guard receiverIDs.contains(receiverID) else { return }
            center.removePendingNotificationRequests(withIdentifiers: Array(cancellations))
            for value in replacements {
                guard receiverIDs.contains(receiverID) else { throw CancellationError() }
                try await center.add(request(for: value, language: language))
                guard receiverIDs.contains(receiverID) else { throw CancellationError() }
            }
            try save(updated, to: fileURL)
            reminders = updated
            for value in replacements { knownTargets[value.id] = value }
            for id in cancellations { knownTargets[id] = current.first(where: { $0.id == id }) }
            center.removeDeliveredNotifications(withIdentifiers: Array(cancellations))
            error = nil
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: replacements.map(\.id))
            knownTargets = previousTargets
            for value in current where value.receiverID == receiverID
                && receiverIDs.contains(value.receiverID) && value.isValid(after: Date()) {
                try? await center.add(request(for: value, language: language))
            }
            if receiverIDs.contains(receiverID) { self.error = "Geänderte Erinnerungen konnten nicht neu geplant werden." }
        }
    }

    private func request(for value: ProgrammeReminder, language: AppLanguage) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = value.programme.title
        let time = value.programme.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale))
        content.body = "\(value.channelName) · \(time)"
        content.sound = .default
        if let data = try? JSONEncoder().encode(value), let encoded = String(data: data, encoding: .utf8) {
            content.userInfo["programmeReminder"] = encoded
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: value.fireDate)
        parts.calendar = calendar; parts.timeZone = calendar.timeZone
        return UNNotificationRequest(identifier: value.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }

    private func save(_ values: [ProgrammeReminder], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: url, options: .atomic)
    }

    private func receiveOpen(identifier: String, decoded: ProgrammeReminder?) {
        if let decoded { knownTargets[identifier] = decoded }
        pendingOpen = knownTargets[identifier] ?? decoded
    }

    func takePendingOpen() -> ProgrammeReminder? {
        defer { pendingOpen = nil }
        return pendingOpen
    }
}
