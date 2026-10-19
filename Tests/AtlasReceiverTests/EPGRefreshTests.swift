import Foundation
import Testing
import os
import AtlasCore
@testable import AtlasReceiver

private struct RefreshFixture: Sendable {
    static let bouquet = "1:7:1:0:0:0:0:0:0:0:FROM BOUQUET \"fixture.tv\" ORDER BY bouquet"
    var apiVersion = "1.4"
    var enabled = false
    var begin = 1_800_000_000
    var end = 1_800_003_600
    var seconds = 120
    var force = true
    var inherit = true
    var references = ["old-service"]
    var availableBouquets = [Self.bouquet]
    var calls: [(String, [String: String])] = []
    var missing = false
    var unauthorized = false
    var failDelete = false
    var ignoreInterval = false
    var ignoreDisable = false

    static func escape(_ s: String) -> String { s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;") }
    func settings() -> Data {
        let values = ["enabled": String(enabled), "begin": String(begin), "end": String(end),
                      "interval_seconds": String(seconds), "force": String(force), "inherit_autotimer": String(inherit)]
        let rows = values.map { "<e2setting><e2settingname>config.plugins.epgrefresh.\($0.key)</e2settingname><e2settingvalue>\($0.value)</e2settingvalue></e2setting>" }.joined()
        return Data(("<e2settings>" + rows + "<e2setting><e2settingname>api_version</e2settingname><e2settingvalue>\(apiVersion)</e2settingvalue></e2setting></e2settings>").utf8)
    }
    func services() -> Data {
        Data(("<epgrefresh version=\"1\">" + references.map { "<e2service><e2servicereference>\(Self.escape($0))</e2servicereference><e2servicename>Fixture</e2servicename></e2service>" }.joined() + "</epgrefresh>").utf8)
    }
    mutating func reply(_ request: URLRequest) -> (Int, Data) {
        let path = request.url?.path ?? ""
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        calls.append((path, query))
        if unauthorized { return (401, Data()) }
        if missing { return (404, Data()) }
        switch path {
        case "/epgrefresh/get": return (200, settings())
        case "/epgrefresh": return (200, services())
        case "/api/currenttime":
            let now = Int(Date().timeIntervalSince1970) % 86400
            return (200, Data(String(format: "{\"status\":true,\"time\":\"%02d:%02d:%02d\"}", now / 3600, now / 60 % 60, now % 60).utf8))
        case "/api/bouquets":
            let object = ["bouquets": availableBouquets.map { [$0, "Fixture bouquet"] }]
            return (200, try! JSONSerialization.data(withJSONObject: object))
        case "/epgrefresh/set":
            if let v = query["enabled"], !(ignoreDisable && v == "false") { enabled = v == "true" }
            if let v = query["begin"].flatMap(Int.init) { begin = v }
            if let v = query["end"].flatMap(Int.init) { end = v }
            if let v = query["interval_seconds"].flatMap(Int.init), !ignoreInterval { seconds = v }
            if let v = query["force"] { force = v == "true" }
            if let v = query["inherit_autotimer"] { inherit = v == "true" }
        case "/epgrefresh/del":
            if failDelete { return (200, Data("<e2simplexmlresult><e2state>False</e2state></e2simplexmlresult>".utf8)) }
            references.removeAll { $0 == query["sref"] }
        case "/epgrefresh/add": if let ref = query["sref"] { references.append(ref) }
        default: return (404, Data())
        }
        return (200, Data("<e2simplexmlresult><e2state>True</e2state></e2simplexmlresult>".utf8))
    }
}

private final class RefreshProtocol: URLProtocol, @unchecked Sendable {
    static let fixture = OSAllocatedUnfairLock(initialState: RefreshFixture())
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.fixture.withLock { $0.reply(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

@Suite("Receiver-side EPG refresh", .serialized)
struct EPGRefreshTests {
    private func client(_ fixture: RefreshFixture = RefreshFixture()) -> OpenWebifClient {
        RefreshProtocol.fixture.withLock { $0 = fixture }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshProtocol.self]
        return OpenWebifClient(profile: ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "", session: URLSession(configuration: configuration))
    }

    @Test func readsXMLAndEscapedBouquetWithoutMutations() async throws {
        var fixture = RefreshFixture(); fixture.references = [RefreshFixture.bouquet]
        let value = try await client(fixture).epgRefreshConfiguration()
        #expect(value.references == [RefreshFixture.bouquet])
        #expect(value.durationSeconds == 120)
        #expect(!value.enabled)
        #expect(value.receiverUTCOffset == 0)
        #expect(RefreshProtocol.fixture.withLock { $0.calls.map(\.0) } == ["/epgrefresh/get", "/epgrefresh", "/api/currenttime"])
    }

    @Test func readsOpenPLi12WithEmptySelectionAtCanonicalRoot() async throws {
        var fixture = RefreshFixture(); fixture.apiVersion = "1.2"; fixture.references = []
        let configuration = try await client(fixture).epgRefreshConfiguration()
        #expect(configuration.references.isEmpty)
        #expect(configuration.durationSeconds == 120)
        let paths = RefreshProtocol.fixture.withLock { $0.calls.map(\.0) }
        #expect(paths.contains("/epgrefresh"))
        #expect(!paths.contains("/epgrefresh/list") && !paths.contains("/epgrefresh/"))
    }

    @Test func receiverClockHandlesOffsetsAndDayRollover() throws {
        let now = Date(timeIntervalSince1970: 23 * 3600 + 30 * 60)
        #expect(try EPGRefreshConfiguration.clockOffset("01:30:00", now: now) == 7200)
        #expect(try EPGRefreshConfiguration.clockOffset("18:00:00", now: now) == -19800)
        #expect(throws: EPGRefreshFailure.self) { try EPGRefreshConfiguration.clockOffset("12:bad:30:00", now: now) }
        #expect(throws: EPGRefreshFailure.self) { try EPGRefreshConfiguration.clockOffset("01:35:00", now: now) }
    }

    @Test func missingPluginAndAuthenticationDoNotWriteOrProbeAlternatives() async {
        var fixture = RefreshFixture(); fixture.missing = true
        do { _ = try await client(fixture).epgRefreshConfiguration(); Issue.record("Missing plugin should fail") }
        catch EPGRefreshFailure.unavailable { }
        catch { Issue.record("Wrong missing-plugin error") }
        #expect(RefreshProtocol.fixture.withLock { $0.calls.count } == 1)
        fixture.missing = false; fixture.unauthorized = true
        do { _ = try await client(fixture).epgRefreshConfiguration(); Issue.record("Authentication should fail") }
        catch AtlasFailure.unauthorized { }
        catch { Issue.record("Wrong authentication error") }
        #expect(RefreshProtocol.fixture.withLock { $0.calls.count } == 1)
    }

    @Test func savesSecondsAndScopeWithoutForcingScan() async throws {
        let client = client()
        let original = try await client.epgRefreshConfiguration()
        var draft = original; draft.enabled = true; draft.durationSeconds = 50
        let saved = try await client.saveEPGRefresh(draft, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
        #expect(saved.enabled && saved.durationSeconds == 50)
        #expect(!saved.force && !saved.inheritsAutoTimer)
        #expect(saved.references == [RefreshFixture.bouquet])
        let mutations = RefreshProtocol.fixture.withLock { $0.calls.filter { ["/epgrefresh/set", "/epgrefresh/add", "/epgrefresh/del"].contains($0.0) } }
        #expect(mutations.map(\.0) == ["/epgrefresh/set", "/epgrefresh/del", "/epgrefresh/add", "/epgrefresh/set"])
        #expect(mutations[0].1 == ["enabled": "false"])
        #expect(mutations[2].1 == ["sref": RefreshFixture.bouquet])
        #expect(mutations.last?.1["interval_seconds"] == "50")
        #expect(!RefreshProtocol.fixture.withLock { $0.calls.contains { $0.0 == "/epgrefresh/refresh" } })
    }

    @Test func savesAllSelectedBouquetsAndRemovesDuplicateReferences() async throws {
        var fixture = RefreshFixture()
        fixture.availableBouquets.append("1:7:1:fixture-second-bouquet")
        let client = client(fixture); let original = try await client.epgRefreshConfiguration()
        var draft = original; draft.durationSeconds = 50
        let bouquets = fixture.availableBouquets.map { Bouquet(id: $0, name: "Fixture") }
        let saved = try await client.saveEPGRefresh(draft, bouquets: bouquets + [bouquets[0]], replacing: original)
        #expect(saved.references == fixture.availableBouquets.sorted())
        #expect(RefreshProtocol.fixture.withLock { $0.calls.filter { $0.0 == "/epgrefresh/add" }.count } == 2)
    }

    @Test func rejectsMalformedAndUnsupportedPluginResponses() throws {
        #expect(throws: EPGRefreshFailure.self) { try EPGRefreshXML.read(Data("<html>Missing plugin</html>".utf8), root: "e2settings") }
        #expect(throws: EPGRefreshFailure.self) { try EPGRefreshXML.read(Data("<e2settings>".utf8), root: "e2settings") }
        let fixture = RefreshFixture()
        let missingSeconds = Data(String(decoding: fixture.settings(), as: UTF8.self).replacingOccurrences(of: "config.plugins.epgrefresh.interval_seconds", with: "config.plugins.epgrefresh.interval").utf8)
        #expect(throws: EPGRefreshFailure.self) {
            try EPGRefreshConfiguration.decode(settings: missingSeconds, services: fixture.services(), clock: "12:00:00", now: Date(timeIntervalSince1970: 43200))
        }
    }

    @Test func changedSettingsAndInvalidTimeDoNotWrite() async throws {
        let client = client(); let original = try await client.epgRefreshConfiguration()
        RefreshProtocol.fixture.withLock { $0.seconds = 121 }
        do {
            _ = try await client.saveEPGRefresh(original, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
            Issue.record("Stale state should fail")
        } catch EPGRefreshFailure.changed { }
        var invalid = original; invalid.begin = Date(timeIntervalSince1970: 1e30)
        do {
            _ = try await client.saveEPGRefresh(invalid, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
            Issue.record("Invalid date should fail")
        } catch EPGRefreshFailure.invalidPlan { }
        #expect(!RefreshProtocol.fixture.withLock { $0.calls.contains { $0.0 == "/epgrefresh/set" } })
    }

    @Test func ignoredDisableNeverChangesChannelList() async throws {
        var fixture = RefreshFixture(); fixture.enabled = true; fixture.ignoreDisable = true
        let client = client(fixture); let original = try await client.epgRefreshConfiguration()
        do {
            _ = try await client.saveEPGRefresh(original, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
            Issue.record("Ignored disable should fail before list changes")
        } catch EPGRefreshFailure.incomplete { }
        #expect(RefreshProtocol.fixture.withLock { $0.references } == ["old-service"])
        #expect(!RefreshProtocol.fixture.withLock { $0.calls.contains { ["/epgrefresh/add", "/epgrefresh/del"].contains($0.0) } })
    }

    @Test func partialFailureDoesNotReenableSchedule() async throws {
        var fixture = RefreshFixture(); fixture.enabled = true; fixture.failDelete = true
        let client = client(fixture); let original = try await client.epgRefreshConfiguration()
        do {
            _ = try await client.saveEPGRefresh(original, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
            Issue.record("Delete refusal should fail")
        } catch EPGRefreshFailure.incomplete { }
        #expect(!RefreshProtocol.fixture.withLock { $0.enabled })
        #expect(!RefreshProtocol.fixture.withLock { $0.calls.contains { $0.0 == "/epgrefresh/add" } })
    }

    @Test func ignoredSettingIsDetectedAndScheduleDisabled() async throws {
        var fixture = RefreshFixture(); fixture.ignoreInterval = true
        let client = client(fixture); let original = try await client.epgRefreshConfiguration()
        var draft = original; draft.enabled = true; draft.durationSeconds = 50
        do {
            _ = try await client.saveEPGRefresh(draft, bouquets: [Bouquet(id: RefreshFixture.bouquet, name: "Fixture")], replacing: original)
            Issue.record("Ignored setting must not report success")
        } catch EPGRefreshFailure.incomplete { }
        #expect(!RefreshProtocol.fixture.withLock { $0.enabled })
    }
}
