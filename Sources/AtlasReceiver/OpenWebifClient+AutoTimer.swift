import Foundation
import AtlasCore

public enum ReceiverAutoTimerFailure: Error, LocalizedError, Sendable {
    case unavailable, rejected
    public var errorDescription: String? {
        switch self {
        case .unavailable: "Das AutoTimer-Plugin ist auf diesem Receiver nicht verfügbar."
        case .rejected: "Der Receiver hat die AutoTimer-Änderung abgelehnt."
        }
    }
}

public extension OpenWebifClient {
    /// Reads AutoTimer's XML rules. Unsupported rule forms remain visible and read-only.
    func autoTimerRules() async throws -> [ReceiverAutoTimerRule] {
        let document = try await readAutoTimerDocument()
        return document.rules
    }

    func addAutoTimer(_ draft: ReceiverAutoTimerDraft) async throws {
        try Self.validate(draft)
        let existing = try await readAutoTimerDocument()
        guard !existing.hasNontrivialDefaults else { throw ReceiverAutoTimerError.unsupportedDefaults }
        try await saveAutoTimer(draft, id: nil)
    }

    func editAutoTimer(_ rule: ReceiverAutoTimerRule, with draft: ReceiverAutoTimerDraft) async throws {
        guard rule.isEditable else { throw ReceiverAutoTimerError.unsupportedRule }
        let current = try await autoTimerRules().first(where: { $0.id == rule.id })
        guard current == rule else { throw ReceiverAutoTimerError.changed }
        try await saveAutoTimer(draft, id: rule.id)
    }

    func deleteAutoTimer(_ rule: ReceiverAutoTimerRule) async throws {
        guard rule.id >= 0, rule.isEditable else { throw ReceiverAutoTimerError.unsupportedRule }
        let current = try await autoTimerRules().first(where: { $0.id == rule.id })
        guard current == rule else { throw ReceiverAutoTimerError.changed }
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "id", value: String(rule.id))]
        guard let query = components.percentEncodedQuery,
              let baseURL, var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw AtlasFailure.invalidAddress }
        url.path = "/autotimer/remove"
        url.percentEncodedQuery = query
        guard let requestURL = url.url else { throw AtlasFailure.invalidAddress }
        let bytes: Data
        do { bytes = try await data(url: requestURL, accept: "application/xml, text/xml, application/xhtml+xml", missingPlugin: true) }
        catch EPGRefreshFailure.unavailable { throw ReceiverAutoTimerFailure.unavailable }
        try Self.checkAutoTimerResult(bytes)
    }

    private func saveAutoTimer(_ draft: ReceiverAutoTimerDraft, id: Int?) async throws {
        try Self.validate(draft)
        guard let baseURL, var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw AtlasFailure.invalidAddress }
        url.path = "/autotimer/edit"
        guard let requestURL = url.url else { throw AtlasFailure.invalidAddress }
        var fields: [URLQueryItem] = [
            URLQueryItem(name: "name", value: draft.title), URLQueryItem(name: "match", value: draft.match),
            URLQueryItem(name: "enabled", value: draft.enabled ? "1" : "0"),
            URLQueryItem(name: "searchType", value: "partial"), URLQueryItem(name: "searchCase", value: "insensitive"),
            URLQueryItem(name: "justplay", value: "0"),
            URLQueryItem(name: "avoidDuplicateDescription", value: draft.allowDuplicate ? "0" : "1"),
            URLQueryItem(name: "offset", value: "\(draft.marginBefore),\(draft.marginAfter)"),
            URLQueryItem(name: "timespanFrom", value: draft.beginTime ?? ""), URLQueryItem(name: "timespanTo", value: draft.endTime ?? ""),
            URLQueryItem(name: "before", value: ""), URLQueryItem(name: "after", value: ""),
            URLQueryItem(name: "title", value: ""), URLQueryItem(name: "shortdescription", value: ""),
            URLQueryItem(name: "description", value: ""), URLQueryItem(name: "dayofweek", value: ""),
            URLQueryItem(name: "!title", value: ""), URLQueryItem(name: "!shortdescription", value: ""),
            URLQueryItem(name: "!description", value: ""), URLQueryItem(name: "!dayofweek", value: "")
        ]
        if let id { fields.append(URLQueryItem(name: "id", value: String(id))) }
        switch draft.target {
        case .service(let ref):
            fields.append(URLQueryItem(name: "services", value: ref)); fields.append(URLQueryItem(name: "bouquets", value: ""))
        case .bouquet(let ref):
            fields.append(URLQueryItem(name: "services", value: "")); fields.append(URLQueryItem(name: "bouquets", value: ref))
        }
        for day in draft.weekdays.sorted() { fields.append(URLQueryItem(name: "dayofweek", value: String(day - 1))) }
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = fields
        guard let bodyString = bodyComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") else { throw ReceiverAutoTimerError.invalidDraft }
        let response: Data
        do { response = try await data(url: requestURL, accept: "application/xml, text/xml, application/xhtml+xml", missingPlugin: true, method: "POST", body: Data(bodyString.utf8)) }
        catch EPGRefreshFailure.unavailable { throw ReceiverAutoTimerFailure.unavailable }
        try Self.checkAutoTimerResult(response)
    }

    private static func validate(_ draft: ReceiverAutoTimerDraft) throws {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.match.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (0...7).contains(draft.weekdays.count), draft.weekdays.allSatisfy({ (1...7).contains($0) }),
              (0...1440).contains(draft.marginBefore), (0...1440).contains(draft.marginAfter),
              (draft.beginTime == nil) == (draft.endTime == nil) else { throw ReceiverAutoTimerError.invalidDraft }
        if let from = draft.beginTime, let to = draft.endTime {
            guard validTime(from), validTime(to) else { throw ReceiverAutoTimerError.invalidDraft }
        }
        switch draft.target {
        case .service(let value), .bouquet(let value):
            guard !value.isEmpty, !value.contains("\n") else { throw ReceiverAutoTimerError.invalidDraft }
        }
    }

    private static func validTime(_ value: String) -> Bool {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 && (0...23).contains(parts[0]) && (0...59).contains(parts[1])
    }

    private func autoTimerData(path: String) async throws -> Data {
        guard let baseURL, var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw AtlasFailure.invalidAddress }
        url.path = path
        guard let requestURL = url.url else { throw AtlasFailure.invalidAddress }
        return try await data(url: requestURL, accept: "application/xml, text/xml, application/xhtml+xml", missingPlugin: true)
    }

    private func readAutoTimerDocument() async throws -> ReceiverAutoTimerXML {
        let bytes: Data
        do { bytes = try await autoTimerData(path: "/autotimer") }
        catch EPGRefreshFailure.unavailable { throw ReceiverAutoTimerFailure.unavailable }
        do { return try ReceiverAutoTimerXML.parse(bytes, expectedRoot: "autotimer") }
        catch AtlasFailure.invalidResponse {
            if let result = try? EPGRefreshXML.read(bytes, root: "e2simplexmlresult"), result.success == false {
                throw ReceiverAutoTimerFailure.unavailable
            }
            throw AtlasFailure.invalidResponse
        }
    }

    private static func checkAutoTimerResult(_ data: Data) throws {
        let result = try EPGRefreshXML.read(data, root: "e2simplexmlresult")
        guard result.success == true else { throw ReceiverAutoTimerError.rejected }
    }
}
