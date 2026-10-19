import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

private final class RecordingStubState: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) -> RecordingStubReply)?

    func set(_ handler: @escaping @Sendable (URLRequest) -> RecordingStubReply) {
        lock.lock(); self.handler = handler; lock.unlock()
    }

    func reply(for request: URLRequest) -> RecordingStubReply {
        lock.lock(); let handler = self.handler; lock.unlock()
        return handler?(request) ?? .response(500, Data())
    }
}

private enum RecordingStubReply: Sendable { case response(Int, Data) }

private final class RecordingStubURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = RecordingStubState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              case let .response(status, data) = Self.state.reply(for: request),
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}

@Suite("OpenWebif recording library", .serialized)
struct ReceiverRecordingTests {
    private func client(reply: @escaping @Sendable (URLRequest) -> RecordingStubReply) -> OpenWebifClient {
        RecordingStubURLProtocol.state.set(reply)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let profile = ReceiverProfile(id: UUID(), name: "Fixture", address: "receiver.test",
                                      username: "user", streamPort: 8001)
        return OpenWebifClient(profile: profile, password: "runtime-only", session: session)
    }

    @Test func decodesOpenWebifMoviesAndChildDirectories() async throws {
        let fixture = #"{"result":true,"directory":"/media/hdd/movie/","bookmarks":["Series","A & B","..","/escape"],"movies":[{"filename":"/media/hdd/movie/News & Weather.ts","serviceref":"1:0:0:0:0:0:0:0:0:0:/media/hdd/movie/News & Weather.ts","eventname":"News & Weather","description":"Daily report","servicename":"Example TV","recordingtime":1800000000,"length":"1:02:03","filesize":123456789},{"filename":"relative.ts","serviceref":"bad","eventname":"invalid"}]}"#
        let data = Data(fixture.utf8)
        let api = client { request in
            #expect(request.url?.path == "/api/movielist")
            return .response(200, data)
        }
        let page = try await api.recordings()
        #expect(page.currentDirectory == "/media/hdd/movie/")
        #expect(page.recordings.count == 1)
        #expect(page.recordings[0].title == "News & Weather")
        #expect(page.recordings[0].serviceReference.hasPrefix("1:0:"))
        #expect(page.recordings[0].description == "Daily report")
        #expect(page.recordings[0].serviceName == "Example TV")
        #expect(page.recordings[0].begin == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(page.recordings[0].duration == 3_723)
        #expect(page.recordings[0].size == 123_456_789)
        #expect(page.recordings[0].filePath == "/media/hdd/movie/News & Weather.ts")
        #expect(page.directories == [
            ReceiverRecordingDirectory(path: "/media/hdd/movie/Series/", name: "Series"),
            ReceiverRecordingDirectory(path: "/media/hdd/movie/A & B/", name: "A & B")
        ])
    }

    @Test func includesReceiverLocationsAndDeduplicatesChildDirectories() async throws {
        let data = Data(#"{"directory":"/media/hdd/movie/","bookmarks":["Series"],"locations":["/media/hdd/movie","/media/hdd/movie/Series","/media/usb/movie/","relative","/media/../etc"],"movies":[]}"#.utf8)
        let api = client { _ in .response(200, data) }
        let page = try await api.recordings()
        #expect(page.directories.map(\.path) == ["/media/hdd/movie/Series/", "/media/usb/movie/"])
    }

    @Test func requestsSelectedDirectoryAsQueryItem() async throws {
        let data = Data(#"{"result":true,"directory":"/media/hdd/movie/A & B/","bookmarks":[],"movies":[]}"#.utf8)
        let api = client { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.queryItems?.first(where: { $0.name == "dirname" })?.value == "/media/hdd/movie/A & B/")
            return .response(200, data)
        }
        let page = try await api.recordings(directory: "/media/hdd/movie/A & B/")
        #expect(page.currentDirectory == "/media/hdd/movie/A & B/")
        #expect(page.recordings.isEmpty)
    }

    @Test func buildsEncodedSameOriginOpenWebifFileURL() async throws {
        let api = client { _ in .response(200, Data()) }
        let recording = ReceiverRecording(serviceReference: "ref", title: "Title", description: "",
                                          serviceName: "", begin: nil, duration: nil, size: nil,
                                          filePath: "/media/hdd/movie/Film & More #1.ts")
        let url = try await api.recordingURL(for: recording)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(url.scheme == "http")
        #expect(url.host == "receiver.test")
        #expect(url.port == nil)
        #expect(url.path == "/file")
        #expect(url.user == nil && url.password == nil)
        #expect(components.queryItems?.first(where: { $0.name == "action" })?.value == "download")
        #expect(components.queryItems?.first(where: { $0.name == "file" })?.value == recording.filePath)
        #expect(url.absoluteString.contains("%26"))
        #expect(url.absoluteString.contains("%23"))
        #expect(!url.absoluteString.contains("runtime-only"))
    }

    @Test(arguments: ["relative.ts", "//outside.test/media.ts", "/media/../etc/passwd", "/media/./secret.ts", "/media\\secret.ts"])
    func rejectsUnexpectedOrTraversingPaths(_ path: String) async throws {
        let api = client { _ in .response(200, Data(#"{"movies":[]}"#.utf8)) }
        let recording = ReceiverRecording(serviceReference: "ref", title: "Title", description: "",
                                          serviceName: "", begin: nil, duration: nil, size: nil, filePath: path)
        await #expect(throws: AtlasFailure.invalidAddress) { try await api.recordingURL(for: recording) }
        await #expect(throws: AtlasFailure.invalidResponse) { try await api.recordings(directory: path) }
    }

    @Test func mapsAuthenticationFailureForRecordingList() async {
        let api = client { _ in .response(401, Data("receiver response body".utf8)) }
        await #expect(throws: AtlasFailure.unauthorized) { try await api.recordings() }
    }

    @Test func rejectsUnexpectedMovieListShape() async {
        let api = client { _ in .response(200, Data(#"{"result":true,"bookmarks":[]}"#.utf8)) }
        await #expect(throws: AtlasFailure.invalidResponse) { try await api.recordings() }
    }
}
