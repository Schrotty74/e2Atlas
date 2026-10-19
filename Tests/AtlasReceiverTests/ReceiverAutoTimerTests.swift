import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

private final class AutoTimerStubState: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) -> (Int, Data))?
    func set(_ value: @escaping @Sendable (URLRequest) -> (Int, Data)) { lock.lock(); handler = value; lock.unlock() }
    func reply(_ request: URLRequest) -> (Int, Data) { lock.lock(); let value = handler; lock.unlock(); return value?(request) ?? (500, Data()) }
}

private final class AutoTimerStubURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = AutoTimerStubState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return }
        var normalized = request
        if normalized.httpBody == nil, let stream = normalized.httpBodyStream {
            stream.open(); defer { stream.close() }
            var body = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            normalized.httpBody = body
        }
        let (status, bytes) = Self.state.reply(normalized)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: bytes)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

@Suite("OpenWebif AutoTimer", .serialized)
struct ReceiverAutoTimerTests {
    private func client(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) -> OpenWebifClient {
        AutoTimerStubURLProtocol.state.set(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AutoTimerStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let profile = ReceiverProfile(id: UUID(), name: "Fixture", address: "receiver.test", username: "user", streamPort: 8001)
        return OpenWebifClient(profile: profile, password: "runtime-only", session: session)
    }

    @Test func listsRulesAndLeavesComplexRulesReadOnly() async throws {
        let xml = #"<?xml version="1.0"?><autotimer version="5"><timer id="7" name="News" match="World" enabled="yes" encoding="UTF-8" from="18:00" to="20:30" offset="5,10"><e2service><e2servicereference>1:0:1:ABC</e2servicereference><e2servicename>Example</e2servicename></e2service><include where="dayofweek">0,4</include></timer><timer id="8" name="Advanced" match="x" enabled="yes" searchType="regex"><include where="title">x</include></timer></autotimer>"#
        let api = client { request in
            #expect(request.url?.path == "/autotimer")
            #expect(request.httpMethod == "GET")
            return (200, Data(xml.utf8))
        }
        let rules = try await api.autoTimerRules()
        #expect(rules.count == 2)
        #expect(rules[0].id == 7 && rules[0].title == "News" && rules[0].match == "World")
        #expect(rules[0].target == .service("1:0:1:ABC"))
        #expect(rules[0].beginTime == "18:00" && rules[0].endTime == "20:30")
        #expect(rules[0].weekdays == [1, 5])
        #expect(rules[0].marginBefore == 5 && rules[0].marginAfter == 10)
        #expect(rules[0].isEditable)
        #expect(!rules[1].isEditable && rules[1].unsupportedFields.contains("searchType"))
    }

    @Test(arguments: ["", #"<defaults id="0"></defaults>"#, #"<defaults id="0" encoding="UTF-8"></defaults>"#])
    func createsRuleUsingFormFieldsAndBouquetTarget(defaults: String) async throws {
        let api = client { request in
            if request.url?.path == "/autotimer" {
                return (200, Data((#"<autotimer version="5">"# + defaults + "</autotimer>").utf8))
            }
            #expect(request.url?.path == "/autotimer/edit")
            #expect(request.httpMethod == "POST")
            let fields = URLComponents(string: "?" + String(decoding: request.httpBody ?? Data(), as: UTF8.self))?.queryItems ?? []
            #expect(fields.first(where: { $0.name == "name" })?.value == "A & B")
            #expect(fields.first(where: { $0.name == "match" })?.value == "Film")
            #expect(fields.first(where: { $0.name == "bouquets" })?.value == "1:7:1:0:0:0:0:0:0:0:")
            #expect(fields.filter { $0.name == "dayofweek" }.compactMap(\.value).filter { !$0.isEmpty } == ["0", "6"])
            #expect(fields.first(where: { $0.name == "offset" })?.value == "3,8")
            #expect(!fields.contains(where: { $0.name == "encoding" }), "The plugin keeps its supported UTF-8 default.")
            return (200, Data(#"<e2simplexmlresult><e2state>true</e2state><e2statetext>ok</e2statetext></e2simplexmlresult>"#.utf8))
        }
        try await api.addAutoTimer(ReceiverAutoTimerDraft(title: "A & B", match: "Film", target: .bouquet("1:7:1:0:0:0:0:0:0:0:"),
            beginTime: "19:00", endTime: "22:00", weekdays: [1, 7], marginBefore: 3, marginAfter: 8))
    }

    @Test(arguments: [#"location="/recordings""#, #"encoding="ISO-8859-15""#])
    func refusesNewRuleWhenReceiverDefaultsContainExtraValues(attributes: String) async {
        let api = client { request in
            #expect(request.url?.path == "/autotimer")
            return (200, Data((#"<autotimer version="5"><defaults id="0" "# + attributes + "></defaults></autotimer>").utf8))
        }
        await #expect(throws: ReceiverAutoTimerError.unsupportedDefaults) {
            try await api.addAutoTimer(ReceiverAutoTimerDraft(title: "Show", match: "Show", target: .service("1:0:1:X")))
        }
    }

    @Test(arguments: ["yes", "no"])
    func receiverDuplicateOptionsRemainEditableAndArePreserved(value: String) async throws {
        let listing = Data((#"<autotimer><timer id="12" name="Synthetic" match="Synthetic" enabled="yes" encoding="UTF-8" avoidDuplicateDescription="1" descShortEqualExt=""# + value + #"" descShortExtEmpty="no"><e2service><e2servicereference>1:0:1:ABC</e2servicereference></e2service></timer></autotimer>"#).utf8)
        let api = client { request in
            if request.url?.path == "/autotimer" { return (200, listing) }
            if request.url?.path == "/autotimer/edit" {
                let fields = URLComponents(string: "?" + String(decoding: request.httpBody ?? Data(), as: UTF8.self))?.queryItems ?? []
                #expect(!fields.contains(where: { ["descShortEqualExt", "descShortExtEmpty"].contains($0.name) }))
                #expect(fields.first(where: { $0.name == "timespanFrom" })?.value == "19:30")
                #expect(fields.first(where: { $0.name == "timespanTo" })?.value == "23:00")
            } else { #expect(request.url?.path == "/autotimer/remove") }
            return (200, Data(#"<e2simplexmlresult><e2state>true</e2state></e2simplexmlresult>"#.utf8))
        }
        let rule = try #require(try await api.autoTimerRules().first)
        #expect(rule.isEditable)
        #expect(rule.descriptionComparisonFlags == ["descShortEqualExt": value, "descShortExtEmpty": "no"])
        try await api.editAutoTimer(rule, with: ReceiverAutoTimerDraft(title: "Synthetic", match: "Synthetic", target: .service("1:0:1:ABC"), beginTime: "19:30", endTime: "23:00"))
        try await api.deleteAutoTimer(rule)
    }

    @Test func editsAndDeletesByRuleID() async throws {
        let rule = ReceiverAutoTimerRule(id: 42, title: "Old", match: "Old", enabled: true, target: .service("1:0:1:A"),
            beginTime: nil, endTime: nil, weekdays: [], marginBefore: 0, marginAfter: 0, allowDuplicate: false,
            isEditable: true, unsupportedFields: [])
        let listing = Data(#"<autotimer version="5"><timer id="42" name="Old" match="Old" enabled="yes" encoding="UTF-8" avoidDuplicateDescription="1"><e2service><e2servicereference>1:0:1:A</e2servicereference><e2servicename>Fixture</e2servicename></e2service></timer></autotimer>"#.utf8)
        let api = client { request in
            if request.url?.path == "/autotimer" { return (200, listing) }
            if request.url?.path == "/autotimer/edit" {
                let values = URLComponents(string: "?" + String(decoding: request.httpBody ?? Data(), as: UTF8.self))?.queryItems
                #expect(values?.first(where: { $0.name == "id" })?.value == "42")
            } else {
                #expect(request.url?.path == "/autotimer/remove")
                #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "42")
            }
            return (200, Data(#"<e2simplexmlresult><e2state>true</e2state><e2statetext>ok</e2statetext></e2simplexmlresult>"#.utf8))
        }
        try await api.editAutoTimer(rule, with: ReceiverAutoTimerDraft(title: "New", match: "Show", target: .service("1:0:1:A")))
        try await api.deleteAutoTimer(rule)
    }

    @Test func refusesComplexRuleAndInvalidDraftWithoutNetworkWrite() async {
        let api = client { _ in (500, Data()) }
        let complex = ReceiverAutoTimerRule(id: 3, title: "Complex", match: "x", enabled: true, target: nil,
            beginTime: nil, endTime: nil, weekdays: [], marginBefore: 0, marginAfter: 0, allowDuplicate: false,
            isEditable: false, unsupportedFields: ["unknown"])
        await #expect(throws: ReceiverAutoTimerError.unsupportedRule) {
            try await api.editAutoTimer(complex, with: ReceiverAutoTimerDraft(title: "x", match: "x", target: .service("ref")))
        }
        await #expect(throws: ReceiverAutoTimerError.invalidDraft) {
            try await api.addAutoTimer(ReceiverAutoTimerDraft(title: "", match: "x", target: .service("ref")))
        }
    }

    @Test func mapsMissingPluginAndRejectsFalseResult() async {
        let missing = client { _ in (404, Data()) }
        await #expect(throws: ReceiverAutoTimerFailure.unavailable) { try await missing.autoTimerRules() }
        let listing = Data(#"<autotimer version="5"><timer id="2" name="x" match="x" enabled="yes" encoding="UTF-8" avoidDuplicateDescription="1"><e2service><e2servicereference>ref</e2servicereference><e2servicename>Fixture</e2servicename></e2service></timer></autotimer>"#.utf8)
        let rejected = client { request in
            if request.url?.path == "/autotimer" { return (200, listing) }
            return (200, Data(#"<e2simplexmlresult><e2state>false</e2state><e2statetext>rejected</e2statetext></e2simplexmlresult>"#.utf8))
        }
        await #expect(throws: ReceiverAutoTimerError.rejected) {
            try await rejected.deleteAutoTimer(ReceiverAutoTimerRule(id: 2, title: "x", match: "x", enabled: true,
                target: .service("ref"), beginTime: nil, endTime: nil, weekdays: [], marginBefore: 0,
                marginAfter: 0, allowDuplicate: false, isEditable: true, unsupportedFields: []))
        }
    }
}
