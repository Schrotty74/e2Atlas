import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

private final class StubState: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: (@Sendable (URLRequest) -> StubReply)?

    func set(_ handler: @escaping @Sendable (URLRequest) -> StubReply) {
        lock.lock()
        stored = handler
        lock.unlock()
    }

    func reply(for request: URLRequest) -> StubReply {
        lock.lock()
        let handler = stored
        lock.unlock()
        return handler?(request) ?? .response(500, Data())
    }
}

private enum StubReply: Sendable {
    case response(Int, Data)
    case suspend
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = StubState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.state.reply(for: request) {
        case let .response(status, data):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status,
                                                 httpVersion: "HTTP/1.1", headerFields: nil) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .suspend:
            break
        }
    }

    override func stopLoading() { }
}

@Suite("OpenWebif fixture responses", .serialized)
struct OpenWebifClientTests {
    private func makeClient(reply: @escaping @Sendable (URLRequest) -> StubReply) -> OpenWebifClient {
        StubURLProtocol.state.set(reply)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let profile = ReceiverProfile(id: UUID(), name: "Fixture", address: "receiver.test",
                                      username: "user", streamPort: 8001)
        return OpenWebifClient(profile: profile, password: "runtime-only", session: session)
    }

    private static func standardTimerRow(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var row: [String: Any] = [
            "serviceref": "1:0:1:ABC", "servicename": "News", "eit": 42, "name": "Evening News",
            "description": "Daily", "begin": 1_800_000_000, "end": 1_800_003_600,
            "disabled": 0, "justplay": 0, "afterevent": 3, "dirname": "/movie/", "tags": "news",
            "repeated": 0, "state": 0, "dontsave": 0, "cancelled": false,
            "vpsplugin_enabled": false, "vpsplugin_overwrite": false, "vpsplugin_time": -1,
            "always_zap": -1, "pipzap": -1, "isAutoTimer": 0, "allow_duplicate": 1,
            "autoadjust": -1, "recordingtype": "normal", "ice_timer_id": -1
        ]
        overrides.forEach { row[$0.key] = $0.value }
        return row
    }

    @Test func decodesBouquetsAndChannels() async throws {
        let client = makeClient { request in
            if request.url?.path == "/api/bouquets" {
                return .response(200, Data(#"{"bouquets":[["1:7:1:0:0:0:0:0:0:0:FROM BOUQUET \"userbouquet.favourites.tv\" ORDER BY bouquet","Favourites"]]}"#.utf8))
            }
            return .response(200, Data(#"{"services":[{"servicereference":"1:0:1:123:2:3:4:0:0:0:","servicename":"News HD"}]}"#.utf8))
        }
        let bouquets = try await client.bouquets()
        #expect(bouquets.count == 1)
        #expect(bouquets[0].name == "Favourites")
        let channels = try await client.channels(in: bouquets[0])
        #expect(channels.count == 1)
        #expect(channels[0].id == "1:0:1:123:2:3:4:0:0:0:")
        #expect(channels[0].number == 1)
    }

    @Test func decodesCurrentOpenWebifEPGFieldsAndSkipsInvalidTimes() async throws {
        let start: Int64 = 1_800_000_000
        let client = makeClient { _ in
            let fixture = #"{"result":true,"events":[{"id":1,"begin_timestamp":1800000000,"duration_sec":3600,"title":"News","shortdesc":"Brief","longdesc":"Full description"},{"begin_timestamp":1e300,"duration_sec":60,"title":"invalid"}]}"#
            return .response(200, Data(fixture.utf8))
        }
        let channel = Channel(id: "1:0:1:123:2:3:4:0:0:0:", name: "News", number: 1)
        let programmes = try await client.programmes(channel: channel,
            from: Date(timeIntervalSince1970: TimeInterval(start - 10)),
            to: Date(timeIntervalSince1970: TimeInterval(start + 7_200)))
        #expect(programmes.count == 1)
        #expect(programmes[0].title == "News")
        #expect(programmes[0].summary == "Full description")
        #expect(programmes[0].end.timeIntervalSince1970 == TimeInterval(start + 3_600))
    }

    @Test func mapsUnauthorizedResponseWithoutExposingDetails() async {
        let client = makeClient { _ in .response(401, Data("sensitive server body".utf8)) }
        do {
            _ = try await client.bouquets()
            Issue.record("Expected unauthorized response")
        } catch let failure as AtlasFailure {
            #expect(failure == .unauthorized)
            #expect(failure.localizedDescription.localizedCaseInsensitiveContains("sensitive") == false)
        } catch {
            Issue.record("Unexpected error type")
        }
    }

    @Test func cancelsAnInFlightRequest() async {
        let client = makeClient { _ in .suspend }
        let task = Task { try await client.bouquets() }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(task.isCancelled)
        } catch {
            Issue.record("Expected CancellationError")
        }
    }

    @Test func fetchesPiconUsingOpenWebifServiceReferenceFilename() async throws {
        let expected = "/picon/1_0_1_44E_3E9_2174_EEEE0000_0_0_0.png"
        let client = makeClient { request in
            #expect(request.url?.path == expected)
            return .response(200, Data([0x89, 0x50, 0x4E, 0x47]))
        }
        let channel = Channel(id: "1:0:1:44E:3E9:2174:EEEE0000:0:0:0:", name: "Example", number: 1)
        let data = try await client.piconData(for: channel)
        #expect(data == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func streamURLPreservesExistingEscapesAndHasNoCredentials() async throws {
        let client = makeClient { _ in .response(200, Data()) }
        let channel = Channel(id: "4097:0:1:0:0:0:0:0:0:0:http%3a//example.test/live", name: "IPTV", number: 1)
        let url = try await client.streamURL(for: channel)
        #expect(url.port == 8001)
        #expect(url.user == nil)
        #expect(url.password == nil)
        #expect(url.absoluteString.contains("http%3a//example.test/live"))
    }
    @Test func decodesBoxInfoAndReportedTunerUsage() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/boxinfo")
            return .response(200, Data(#"{"brand":"Example","model":"DVB Receiver","imagedistro":"example-image","chipset":"example-chip","mem3":"512 MB free / 2 GB total","ifaces":[{"mac":"discard-this"}],"tuners":[{"name":"Tuner A","type":"DVB-S2 FBC","live":"19.2E / Example","rec":"","stream":"19.2E / Example"},{"name":"Tuner B","type":"DVB-S2","live":"","rec":"19.2E / Recording","stream":""},{"name":"Tuner C","type":"DVB-S2","live":"","rec":"","stream":""}]}"#.utf8))
        }
        let info = try await client.hardwareInfo()
        #expect(info.model == "DVB Receiver")
        #expect(info.chipset == "example-chip")
        #expect(info.tuners.count == 3)
        #expect(info.activeTunerCount == 2)
        #expect(info.allTunerStatusesAvailable)
        #expect(info.tuners[0].live && info.tuners[0].streaming)
        #expect(info.tuners[1].recording)
        #expect(!info.tuners[2].isActive)
    }

    @Test func fallsBackToLegacyAboutWithoutInventingTunerStatus() async throws {
        let client = makeClient { request in
            if request.url?.path == "/api/boxinfo" { return .response(404, Data()) }
            #expect(request.url?.path == "/api/about")
            return .response(200, Data(#"{"info":{"model":"Legacy Receiver","tuners":[{"name":"Tuner A","type":"DVB-C"}]}}"#.utf8))
        }
        let info = try await client.hardwareInfo()
        #expect(info.model == "Legacy Receiver")
        #expect(info.tuners.count == 1)
        #expect(!info.tuners[0].statusAvailable)
        #expect(!info.allTunerStatusesAvailable)
    }

    @Test func preservesUnknownMissingTunersAndPartialUsage() throws {
        let missing = try ReceiverHardware.decode(["model": "Receiver"])
        #expect(!missing.tunerListAvailable)
        #expect(!missing.allTunerStatusesAvailable)
        let partial = try ReceiverHardware.decode(["model": "Receiver", "EX": "synthetic status failure",
            "tuners": [["name": "A", "live": "", "rec": "", "stream": ""],
                       ["name": "B", "stream": "Example stream"]]])
        #expect(!partial.tuners[0].statusAvailable)
        #expect(!partial.tuners[0].isActive)
        #expect(partial.tuners[1].isActive)
        #expect(!partial.tuners[1].statusAvailable)
    }

    @Test func hardwareAuthenticationFailureDoesNotTryOtherEndpoints() async {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/boxinfo")
            return .response(401, Data())
        }
        await #expect(throws: AtlasFailure.unauthorized) { try await client.hardwareInfo() }
    }

    @Test func verifiesModernAboutVersionOnlyUsingBoxInfo() async throws {
        let client = makeClient { request in
            if request.url?.path == "/api/about" {
                return .response(200, Data(#"{"info":{"owiver":"2.0"}}"#.utf8))
            }
            #expect(request.url?.path == "/api/boxinfo")
            return .response(200, Data(#"{"brand":"Example","model":"Receiver","imagedistro":"example-image"}"#.utf8))
        }
        let info = try await client.verify()
        #expect(info.name == "Example Receiver")
        #expect(info.image == "example-image")
    }

    @Test func rejectsVersionOnlyHardwareResponse() async {
        let client = makeClient { _ in .response(200, Data(#"{"info":{"owiver":"2.0"}}"#.utf8)) }
        await #expect(throws: AtlasFailure.invalidResponse) { try await client.hardwareInfo() }
    }

    @Test func marksUnmappedFBCStreamsAsIncompleteInsteadOfCountingThemAsTuners() throws {
        let info = try ReceiverHardware.decode(["model": "FBC Fixture", "tuners": [
            ["name": "A", "live": "Example TV", "rec": "", "stream": ""],
            ["name": "B", "live": "", "rec": "", "stream": ""],
            ["name": "C", "live": "", "rec": "", "stream": ""]],
            "streams": [["ref": "synthetic-1", "type": "stream"], ["ref": "synthetic-2", "type": "stream"]]])
        #expect(info.activeTunerCount == 1)
        #expect(info.streamCount == 2)
        #expect(info.unassignedStreamCount == 2)
        #expect(!info.allTunerStatusesAvailable)
        #expect(!info.tuners[1].statusAvailable)
    }

    @Test func mapsStreamTunerIDsAndCountsSharedFrontendsOnce() throws {
        let info = try ReceiverHardware.decode(["model": "FBC Fixture", "tuners": [
            ["name": "A", "live": "Example TV", "rec": "", "stream": ""],
            ["name": "B", "live": "", "rec": "", "stream": ""]],
            "streams": [["tuner_number": 0], ["tuner_number": "1"], ["tuner_number": 1]]])
        #expect(info.activeTunerCount == 2)
        #expect(info.streamCount == 3)
        #expect(info.unassignedStreamCount == 0)
        #expect(info.allTunerStatusesAvailable)
        #expect(info.tuners[0].streaming && info.tuners[1].streaming)
    }

    @Test func rejectsInvalidStreamTunerIDsWithoutInventingUsage() throws {
        let info = try ReceiverHardware.decode(["model": "Fixture", "tuners": [
            ["name": "A", "live": "", "rec": "", "stream": ""]],
            "streams": [["tuner_number": true], ["tuner_number": -1], ["tuner_number": 999],
                        ["tuner_number": 0.5], ["tuner_number": "invalid"]]])
        #expect(info.activeTunerCount == 0)
        #expect(info.unassignedStreamCount == 5)
        #expect(!info.allTunerStatusesAvailable)
    }

    @Test func decodesTimerListAndSkipsMalformedRows() async throws {
        let normalWithBooleanFlags = Self.standardTimerRow([
            "disabled": false, "justplay": false, "cancelled": false, "dontsave": false,
            "vpsplugin_enabled": false, "vpsplugin_overwrite": false, "isAutoTimer": false
        ])
        let data = try JSONSerialization.data(withJSONObject: ["result": true, "timers": [
            normalWithBooleanFlags, normalWithBooleanFlags,
            ["serviceref": "bad-fraction", "begin": 1_800_000_000.5, "end": 1_800_003_600],
            ["name": "bad"]
        ]])
        let client = makeClient { request in
            #expect(request.url?.path == "/api/timerlist")
            return .response(200, data)
        }
        let timers = try await client.timers()
        // Identical composite identities must not generate duplicate SwiftUI rows or ambiguous mutations.
        #expect(timers.count == 1)
        #expect(timers[0].name == "Evening News")
        #expect(timers[0].eventID == 42)
        #expect(timers[0].begin.timeIntervalSince1970 == 1_800_000_000)
        #expect(timers[0].isEditable)
    }

    @Test func keepsVendorFieldsAndMalformedNumericRowsOutOfEditableModel() throws {
        let ordinary = ReceiverTimer.decode(Self.standardTimerRow([
            "end": 1_800_000_600, "allow_duplicate": 0, "autoadjust": 1
        ]))!
        #expect(ordinary.isEditable)
        let defaultDirectory = ReceiverTimer.decode(Self.standardTimerRow(["dirname": "None"]))!
        let defaultDraft = ReceiverTimerDraft(editing: defaultDirectory)
        #expect(defaultDraft.directory.isEmpty)
        #expect(!defaultDraft.queryItems.contains { $0.name == "dirname" })
        #expect(ReceiverTimerDraft(editing: ordinary).queryItems.contains { $0.name == "dirname" && $0.value == ordinary.directory })
        let vendor = ReceiverTimer.decode(Self.standardTimerRow([
            "end": 1_800_000_600, "vendor_feature": "enabled"
        ]))!
        #expect(!vendor.isEditable)
        #expect(ReceiverTimer.decode(Self.standardTimerRow([
            "begin": 1_800_000_000.5, "end": 1_800_000_600
        ])) == nil)
        #expect(ReceiverTimer.decode(Self.standardTimerRow([
            "begin": 1e300, "end": 1_800_000_600
        ])) == nil)
        #expect(ReceiverTimer.decode(Self.standardTimerRow(["isAutoTimer": -1]))!.isEditable)
        #expect(!ReceiverTimer.decode(Self.standardTimerRow(["isAutoTimer": -1, "tags": "news AutoTimer"]))!.isEditable)
        var missingAutoTimerStatus = Self.standardTimerRow()
        missingAutoTimerStatus.removeValue(forKey: "isAutoTimer")
        #expect(!ReceiverTimer.decode(missingAutoTimerStatus)!.isEditable)
        #expect(!ReceiverTimer.decode(Self.standardTimerRow(["dontsave": true]))!.isEditable)
        #expect(!ReceiverTimer.decode(Self.standardTimerRow(["disabled": 2]))!.isEditable)
        #expect(!ReceiverTimer.decode(Self.standardTimerRow(["vpsplugin_enabled": 2]))!.isEditable)
        #expect(!ReceiverTimer.decode(Self.standardTimerRow(["isAutoTimer": true]))!.isEditable)
    }

    @Test func addTimerEncodesServiceReferenceAndTextAndChecksResult() async throws {
        let client = makeClient { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/timeradd")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items.first(where: { $0.name == "sRef" })?.value == "4097:0:1:IPTV%3a//station.test/live")
            #expect(items.first(where: { $0.name == "name" })?.value == "News & Culture")
            #expect(items.first(where: { $0.name == "begin" })?.value == "1800000000")
            return .response(200, Data(#"{"result":true,"message":"ok"}"#.utf8))
        }
        let draft = ReceiverTimerDraft(serviceReference: "4097:0:1:IPTV%3a//station.test/live",
                                       begin: Date(timeIntervalSince1970: 1_800_000_000),
                                       end: Date(timeIntervalSince1970: 1_800_000_600), name: "News & Culture")
        try await client.addTimer(draft)
    }

    @Test func editAndDeleteUseOriginalCompositeIdentityAndSurfaceGenericConflicts() async throws {
        let timer = ReceiverTimer.decode(Self.standardTimerRow([
            "name": "Old", "end": 1_800_000_600, "allow_duplicate": 0, "autoadjust": 1
        ]))!
        let client = makeClient { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            if request.url?.path == "/api/timerchange" {
                #expect(values["channelOld"] == "1:0:1:ABC")
                #expect(values["beginOld"] == "1800000000")
                #expect(values["endOld"] == "1800000600")
                #expect(values["allow_duplicate"] == "0")
                #expect(values["autoadjust"] == "1")
                return .response(200, Data(#"{"result":true}"#.utf8))
            }
            #expect(request.url?.path == "/api/timerdelete")
            #expect(values["sRef"] == "1:0:1:ABC")
            #expect(values["begin"] == "1800000000")
            #expect(values["end"] == "1800000600")
            return .response(200, Data(#"{"result":false,"message":"sensitive raw server details","conflicts":[]}"#.utf8))
        }
        try await client.editTimer(timer, with: ReceiverTimerDraft(editing: timer))
        do {
            try await client.deleteTimer(timer)
            Issue.record("Expected conflict error")
        } catch let error as ReceiverTimerMutationError {
            #expect(error == .conflict)
            #expect(error.localizedDescription.localizedCaseInsensitiveContains("sensitive") == false)
        }
    }

    @Test func timerMutationRequiresBooleanResultAndFutureEnd() async throws {
        let client = makeClient { request in
            #expect(request.url?.path == "/api/timeradd")
            return .response(200, Data(#"{"result":"true"}"#.utf8))
        }
        let now = Date()
        let draft = ReceiverTimerDraft(serviceReference: "1:0:1:ABC", begin: now,
                                       end: now.addingTimeInterval(600), name: "Future")
        do {
            try await client.addTimer(draft)
            Issue.record("Expected malformed-result failure")
        } catch let error as AtlasFailure {
            #expect(error == .invalidResponse)
        }
        let expired = ReceiverTimerDraft(serviceReference: "1:0:1:ABC",
                                         begin: now.addingTimeInterval(-600),
                                         end: now.addingTimeInterval(-1), name: "Expired")
        await #expect(throws: AtlasFailure.invalidResponse) { try await client.addTimer(expired) }
    }

}
