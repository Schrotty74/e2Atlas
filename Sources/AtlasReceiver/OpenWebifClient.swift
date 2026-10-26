import Foundation
import CoreFoundation
import AtlasCore

// The delegate is retained by URLSession and only reads immutable origin and credential values.
private final class ReceiverSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let origin: URL?
    let username: String
    let password: String

    init(origin: URL?, username: String, password: String) {
        self.origin = origin
        self.username = username
        self.password = password
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard challenge.previousFailureCount == 0,
              let origin,
              space.host.lowercased() == origin.host?.lowercased(),
              space.port == (origin.port ?? (origin.scheme == "https" ? 443 : 80)),
              space.protocol?.lowercased() == origin.scheme?.lowercased() else {
            completionHandler(.rejectProtectionSpace, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: username, password: password, persistence: .forSession))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let from = response.url, let to = request.url, Self.sameOrigin(from, to) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && (lhs.port ?? (lhs.scheme == "https" ? 443 : 80)) == (rhs.port ?? (rhs.scheme == "https" ? 443 : 80))
    }
}

public actor OpenWebifClient {
    public nonisolated let profile: ReceiverProfile
    let baseURL: URL?
    private let session: URLSession

    public init(profile: ReceiverProfile, password: String) {
        self.profile = profile
        let resolved = try? ReceiverAddress.resolve(profile.address)
        self.baseURL = resolved
        let delegate = ReceiverSessionDelegate(origin: resolved, username: profile.username, password: password)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    init(profile: ReceiverProfile, password: String, session: URLSession) {
        self.profile = profile
        self.baseURL = try? ReceiverAddress.resolve(profile.address)
        self.session = session
    }

    deinit { session.invalidateAndCancel() }

    public func verify() async throws -> ReceiverInfo {
        let json = try await object(path: "/api/about")
        guard let info = json["info"] as? [String: Any] else { throw AtlasFailure.invalidResponse }
        let model = info["model"] as? String ?? ""
        let brand = info["brand"] as? String ?? ""
        let distro = info["imagedistro"] as? String ?? ""
        let name = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        let image = distro.isEmpty ? (info["oever"] as? String ?? "") : distro
        guard !name.isEmpty || !image.isEmpty else {
            let hardware = try await hardwareInfo()
            let hardwareName = [hardware.brand, hardware.model].compactMap { $0 }.joined(separator: " ")
            return ReceiverInfo(name: hardwareName.isEmpty ? "Enigma2" : hardwareName, image: hardware.image ?? "")
        }
        return ReceiverInfo(name: name.isEmpty ? "Enigma2" : name, image: image)
    }

    public func hardwareInfo() async throws -> ReceiverHardware {
        do {
            return try ReceiverHardware.decode(await object(path: "/api/boxinfo"))
        } catch AtlasFailure.invalidResponse {
            // Older OpenWebif versions expose hardware under info in /api/about.
            return try ReceiverHardware.decode(await object(path: "/api/about"))
        }
    }

    public func bouquets() async throws -> [Bouquet] {
        let json = try await object(path: "/api/bouquets", query: [URLQueryItem(name: "stype", value: "tv")])
        guard let values = json["bouquets"] as? [[Any]] else { throw AtlasFailure.invalidResponse }
        return values.compactMap { row in
            guard row.count >= 2, let id = row[0] as? String, let name = row[1] as? String else { return nil }
            return Bouquet(id: id, name: name)
        }
    }

    public func channels(in bouquet: Bouquet) async throws -> [Channel] {
        let json = try await object(path: "/api/getservices", query: [URLQueryItem(name: "sRef", value: bouquet.id)])
        guard let values = json["services"] as? [[String: Any]] else { throw AtlasFailure.invalidResponse }
        return values.enumerated().compactMap { index, row in
            guard let id = row["servicereference"] as? String,
                  let name = row["servicename"] as? String else { return nil }
            return Channel(id: id, name: name, number: index + 1)
        }
    }

    public func programmes(channel: Channel, from: Date, to: Date) async throws -> [Programme] {
        guard to > from else { return [] }
        let fromEpoch = from.timeIntervalSince1970
        let toEpoch = to.timeIntervalSince1970
        guard fromEpoch.isFinite, toEpoch.isFinite,
              fromEpoch >= Double(Int64.min), fromEpoch <= Double(Int64.max),
              toEpoch >= Double(Int64.min), toEpoch <= Double(Int64.max) else {
            throw AtlasFailure.invalidResponse
        }
        let query = [
            URLQueryItem(name: "sRef", value: channel.id),
            URLQueryItem(name: "time", value: String(Int64(fromEpoch))),
            URLQueryItem(name: "endTime", value: String(Int64(toEpoch)))
        ]
        let json = try await object(path: "/api/epgservice", query: query)
        guard let values = json["events"] as? [[String: Any]] else { throw AtlasFailure.invalidResponse }
        return values.compactMap { row in
            guard let begin = Self.date(row["begin_timestamp"] ?? row["begin"]),
                  let duration = Self.number(row["duration_sec"] ?? row["duration"]),
                  duration > 0, duration.isFinite,
                  let title = row["title"] as? String else { return nil }
            let end = begin.addingTimeInterval(duration)
            let epoch = begin.timeIntervalSince1970
            guard epoch.isFinite, epoch >= Double(Int64.min), epoch <= Double(Int64.max),
                  end.timeIntervalSince1970.isFinite, end > from, begin < to else { return nil }
            let summary = (row["longdesc"] as? String) ?? (row["shortdesc"] as? String) ?? (row["description"] as? String) ?? ""
            let id = "\(channel.id)|\(Int64(epoch))"
            return Programme(id: id, channelID: channel.id, title: title, summary: summary, start: begin, end: end)
        }.sorted { $0.start < $1.start }
    }

    public func timers() async throws -> [ReceiverTimer] {
        let json = try await object(path: "/api/timerlist")
        guard let rows = json["timers"] as? [[String: Any]] else { throw AtlasFailure.invalidResponse }
        var seen = Set<String>()
        return rows.compactMap(ReceiverTimer.decode).filter { seen.insert($0.id).inserted }
    }

    /// Lists recordings and their immediate subdirectories from OpenWebif's movielist API.
    public func recordings(directory: String? = nil) async throws -> ReceiverRecordingPage {
        var query: [URLQueryItem] = []
        if let directory {
            guard ReceiverRecording.validReceiverPath(directory) else { throw AtlasFailure.invalidResponse }
            query.append(URLQueryItem(name: "dirname", value: directory))
        }
        let json = try await object(path: "/api/movielist", query: query)
        guard let rows = json["movies"] as? [[String: Any]] else { throw AtlasFailure.invalidResponse }
        let currentDirectory = (json["directory"] as? String).flatMap {
            ReceiverRecording.validReceiverPath($0) ? $0 : nil
        }
        var directories = (json["bookmarks"] as? [String] ?? []).compactMap { name -> ReceiverRecordingDirectory? in
            guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
                  let currentDirectory else { return nil }
            let parent = currentDirectory.hasSuffix("/") ? currentDirectory : currentDirectory + "/"
            let path = parent + name + "/"
            guard ReceiverRecording.validReceiverPath(path) else { return nil }
            return ReceiverRecordingDirectory(path: path, name: name)
        }
        for path in json["locations"] as? [String] ?? [] where ReceiverRecording.validReceiverPath(path) {
            guard path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != currentDirectory?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) else { continue }
            directories.append(ReceiverRecordingDirectory(path: path, name: path.split(separator: "/").last.map(String.init) ?? path))
        }
        var seenDirectories = Set<String>()
        directories = directories.filter { seenDirectories.insert($0.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).inserted }
        return ReceiverRecordingPage(
            recordings: rows.compactMap(ReceiverRecording.decode),
            directories: directories,
            currentDirectory: currentDirectory
        )
    }

    /// Builds the same-origin OpenWebif file endpoint for receiver-side playback.
    /// Playback clients must supply configured credentials separately; this URL contains none.
    public func recordingURL(for recording: ReceiverRecording) throws -> URL {
        guard ReceiverRecording.validReceiverPath(recording.filePath),
              let baseURL, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AtlasFailure.invalidAddress
        }
        components.path = "/file"
        components.queryItems = [
            URLQueryItem(name: "action", value: "download"),
            URLQueryItem(name: "file", value: recording.filePath)
        ]
        components.user = nil
        components.password = nil
        guard let url = components.url, Self.sameOrigin(baseURL, url) else { throw AtlasFailure.invalidAddress }
        return url
    }

    public func addTimer(_ draft: ReceiverTimerDraft) async throws {
        guard draft.end > draft.begin, draft.end > Date(), !draft.serviceReference.isEmpty else { throw AtlasFailure.invalidResponse }
        guard Self.validTimerDate(draft.begin), Self.validTimerDate(draft.end) else { throw AtlasFailure.invalidResponse }
        try await timerMutation(path: "/api/timeradd", query: draft.queryItems)
    }

    public func editTimer(_ timer: ReceiverTimer, with draft: ReceiverTimerDraft) async throws {
        guard timer.isEditable, draft.end > draft.begin, draft.end > Date(), !draft.serviceReference.isEmpty else {
            throw AtlasFailure.unsupported("Dieser Timer-Typ kann in e2Atlas nicht bearbeitet werden.")
        }
        guard Self.validTimerDate(draft.begin), Self.validTimerDate(draft.end) else { throw AtlasFailure.invalidResponse }
        let query = draft.queryItems + [
            URLQueryItem(name: "channelOld", value: timer.serviceReference),
            URLQueryItem(name: "beginOld", value: String(timer.beginEpoch)),
            URLQueryItem(name: "endOld", value: String(timer.endEpoch))
        ]
        try await timerMutation(path: "/api/timerchange", query: query)
    }

    public func deleteTimer(_ timer: ReceiverTimer) async throws {
        let query = [
            URLQueryItem(name: "sRef", value: timer.serviceReference),
            URLQueryItem(name: "begin", value: String(timer.beginEpoch)),
            URLQueryItem(name: "end", value: String(timer.endEpoch))
        ]
        try await timerMutation(path: "/api/timerdelete", query: query)
    }

    private func timerMutation(path: String, query: [URLQueryItem]) async throws {
        let json = try await object(path: path, query: query, checkResult: false)
        guard let result = Self.jsonBoolean(json["result"]) else { throw AtlasFailure.invalidResponse }
        guard result else {
            if json["conflicts"] != nil {
                let timers = (json["conflicts"] as? [[String: Any]] ?? []).compactMap(ReceiverTimer.decode)
                if !timers.isEmpty { throw ReceiverTimerConflict(timers: timers) }
                throw ReceiverTimerMutationError.conflict
            }
            throw ReceiverTimerMutationError.rejected
        }
    }

    private static func validTimerDate(_ date: Date) -> Bool {
        let value = date.timeIntervalSince1970
        return value.isFinite && value >= -62_135_596_800 && value <= 253_402_300_799
    }

    private static func jsonBoolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    public func piconData(for channel: Channel) async throws -> Data {
        let reference = channel.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reference.isEmpty else { throw AtlasFailure.invalidResponse }
        let escaped = reference.split(separator: ":", omittingEmptySubsequences: false).prefix(10).joined(separator: "_")
        guard escaped.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0) }) else { throw AtlasFailure.invalidResponse }
        guard let baseURL else { throw AtlasFailure.invalidAddress }
        let url = baseURL.appendingPathComponent("picon", isDirectory: true).appendingPathComponent(escaped + ".png")
        return try await data(url: url)
    }

    public func streamURL(for channel: Channel) throws -> URL {
        guard (1...65535).contains(profile.streamPort), !channel.id.isEmpty,
              let baseURL, baseURL.host != nil,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AtlasFailure.invalidAddress
        }
        guard let escapedReference = Self.encodeServiceReferencePath(channel.id) else {
            throw AtlasFailure.invalidResponse
        }
        components.port = profile.streamPort
        components.percentEncodedPath = "/\(escapedReference)"
        components.user = nil
        components.password = nil
        guard let url = components.url else { throw AtlasFailure.invalidAddress }
        return url
    }

    public func epgRefreshConfiguration() async throws -> EPGRefreshConfiguration {
        let settings = try await epgRefreshData("get")
        let services = try await epgRefreshData("")
        let before = Date()
        let time = try await object(path: "/api/currenttime")
        let midpoint = before.addingTimeInterval(Date().timeIntervalSince(before) / 2)
        guard let clock = time["time"] as? String else { throw EPGRefreshFailure.clockUnavailable }
        return try EPGRefreshConfiguration.decode(settings: settings, services: services, clock: clock, now: midpoint)
    }

    /// Stores a receiver-side schedule, never forces an immediate channel switch.
    public func saveEPGRefresh(_ draft: EPGRefreshConfiguration, bouquets: [Bouquet], replacing original: EPGRefreshConfiguration) async throws -> EPGRefreshConfiguration {
        let references = Array(Set(bouquets.map(\.id))).sorted()
        guard !references.isEmpty, references.allSatisfy({ !$0.isEmpty }),
              (1...86400).contains(draft.durationSeconds),
              (-62_135_596_800...253_402_300_799).contains(draft.begin.timeIntervalSince1970),
              (-62_135_596_800...253_402_300_799).contains(draft.end.timeIntervalSince1970),
              draft.minute(draft.begin) != draft.minute(draft.end) else { throw EPGRefreshFailure.invalidPlan }
        let current = try await epgRefreshConfiguration()
        guard current.matches(original) else { throw EPGRefreshFailure.changed }
        let available = Set(try await self.bouquets().map(\.id))
        guard references.allSatisfy(available.contains) else { throw EPGRefreshFailure.invalidPlan }
        var finalSettingsAttempted = false
        do {
            // Disable scheduled runs while replacing a non-transactional plugin list.
            try await epgRefreshMutation("set", query: [URLQueryItem(name: "enabled", value: "false")])
            var expectedPaused = current
            expectedPaused.enabled = false
            let paused = try await epgRefreshConfiguration()
            guard paused.matches(expectedPaused) else { throw EPGRefreshFailure.incomplete }
            for reference in current.references {
                try await epgRefreshMutation("del", query: [URLQueryItem(name: "sref", value: reference)])
            }
            // Omitting duration removes old per-entry overrides; the global seconds value applies.
            for reference in references {
                try await epgRefreshMutation("add", query: [URLQueryItem(name: "sref", value: reference)])
            }
            finalSettingsAttempted = true
            try await epgRefreshMutation("set", query: [
                URLQueryItem(name: "enabled", value: draft.enabled ? "true" : "false"),
                URLQueryItem(name: "begin", value: String(Int64(draft.begin.timeIntervalSince1970))),
                URLQueryItem(name: "end", value: String(Int64(draft.end.timeIntervalSince1970))),
                URLQueryItem(name: "interval_seconds", value: String(draft.durationSeconds)),
                URLQueryItem(name: "force", value: "false"),
                URLQueryItem(name: "inherit_autotimer", value: "false")
            ])
            let saved = try await epgRefreshConfiguration()
            guard saved.enabled == draft.enabled, saved.minute(saved.begin) == draft.minute(draft.begin),
                  saved.minute(saved.end) == draft.minute(draft.end), saved.durationSeconds == draft.durationSeconds,
                  saved.references == references, !saved.force, !saved.inheritsAutoTimer else { throw EPGRefreshFailure.incomplete }
            return saved
        } catch {
            if finalSettingsAttempted {
                try? await epgRefreshMutation("set", query: [URLQueryItem(name: "enabled", value: "false")])
            }
            throw EPGRefreshFailure.incomplete
        }
    }

    private func epgRefreshMutation(_ action: String, query: [URLQueryItem]) async throws {
        let result = try EPGRefreshXML.read(await epgRefreshData(action, query: query), root: "e2simplexmlresult")
        guard result.success == true else { throw EPGRefreshFailure.incomplete }
    }

    private func epgRefreshData(_ action: String, query: [URLQueryItem] = []) async throws -> Data {
        guard let baseURL, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw AtlasFailure.invalidAddress }
        components.path = action.isEmpty ? "/epgrefresh" : "/epgrefresh/" + action
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw AtlasFailure.invalidAddress }
        return try await data(url: url, accept: "application/xml, text/xml, application/xhtml+xml", missingPlugin: true)
    }

    func object(path: String, query: [URLQueryItem] = [], checkResult: Bool = true) async throws -> [String: Any] {
        guard let baseURL else { throw AtlasFailure.invalidAddress }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw AtlasFailure.invalidAddress }
        let bytes = try await data(url: url)
        guard let value = try? JSONSerialization.jsonObject(with: bytes), let object = value as? [String: Any] else {
            throw AtlasFailure.invalidResponse
        }
        if checkResult, let result = object["result"] as? Bool, !result { throw AtlasFailure.invalidResponse }
        return object
    }

    func data(url: URL, accept: String = "application/json, image/*;q=0.8", missingPlugin: Bool = false, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let baseURL, Self.sameOrigin(baseURL, url) else { throw AtlasFailure.invalidAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type") }
        request.timeoutInterval = 15
        request.setValue(accept, forHTTPHeaderField: "Accept")
        do {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw AtlasFailure.invalidResponse }
            switch response.statusCode {
            case 200..<300: return data
            case 401, 403: throw AtlasFailure.unauthorized
            case 404, 501:
                if missingPlugin { throw EPGRefreshFailure.unavailable }
                throw AtlasFailure.invalidResponse
            default: throw AtlasFailure.invalidResponse
            }
        } catch is CancellationError { throw CancellationError() }
        catch let error as AtlasFailure { throw error }
        catch let error as EPGRefreshFailure { throw error }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as URLError where error.code == .userAuthenticationRequired { throw AtlasFailure.unauthorized }
        catch let error as URLError where error.code == .timedOut { throw AtlasFailure.unreachable }
        catch { throw AtlasFailure.unreachable }
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && (lhs.port ?? (lhs.scheme == "https" ? 443 : 80)) == (rhs.port ?? (rhs.scheme == "https" ? 443 : 80))
    }

    private static func encodeServiceReferencePath(_ reference: String) -> String? {
        let bytes = Array(reference.utf8)
        var result = ""
        let safeCharacters = Set("-._~:/".utf8)
        let safe: (UInt8) -> Bool = { byte in
            (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
                || (byte >= 48 && byte <= 57) || safeCharacters.contains(byte)
        }
        func isHex(_ byte: UInt8) -> Bool {
            (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 70) || (byte >= 97 && byte <= 102)
        }
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 37, index + 2 < bytes.count, isHex(bytes[index + 1]), isHex(bytes[index + 2]) {
                result += String(decoding: bytes[index...index + 2], as: UTF8.self)
                index += 3
            } else if safe(byte) {
                result.append(Character(UnicodeScalar(byte)))
                index += 1
            } else {
                result += String(format: "%%%02X", byte)
                index += 1
            }
        }
        return result
    }

    private static func number(_ value: Any?) -> Double? {
        let parsed: Double?
        if let number = value as? NSNumber { parsed = number.doubleValue }
        else if let string = value as? String { parsed = Double(string) }
        else { return nil }
        guard let parsed, parsed.isFinite else { return nil }
        return parsed
    }

    private static func date(_ value: Any?) -> Date? {
        guard let seconds = number(value), seconds >= -62_135_596_800, seconds <= 253_402_300_799 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
