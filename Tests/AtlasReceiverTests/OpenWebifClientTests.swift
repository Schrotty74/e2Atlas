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
}
