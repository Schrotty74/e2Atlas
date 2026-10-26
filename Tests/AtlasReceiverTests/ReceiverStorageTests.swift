import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

private final class StorageReplyState: @unchecked Sendable {
    private let lock = NSLock()
    private var reply: (Int, Data) = (500, Data())
    private var requestPath: String?
    private var boxInfoMissing = false

    func set(_ value: (Int, Data), boxInfoMissing: Bool) { lock.lock(); reply = value; self.boxInfoMissing = boxInfoMissing; lock.unlock() }
    func record(path: String?) { lock.lock(); requestPath = path; lock.unlock() }
    func lastPath() -> String? { lock.lock(); defer { lock.unlock() }; return requestPath }
    func get(path: String) -> (Int, Data) { lock.lock(); defer { lock.unlock() }; return boxInfoMissing && path == "/api/boxinfo" ? (404, Data()) : reply }
}

private final class StorageURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = StorageReplyState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return }
        Self.state.record(path: url.path)
        let (status, data) = Self.state.get(path: url.path)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

@Suite("OpenWebif receiver storage", .serialized)
struct ReceiverStorageTests {
    private func client(status: Int = 200, json: String, boxInfoMissing: Bool = false) -> OpenWebifClient {
        StorageURLProtocol.state.set((status, Data(json.utf8)), boxInfoMissing: boxInfoMissing)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StorageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let profile = ReceiverProfile(id: UUID(), name: "Fixture", address: "receiver.test",
                                      username: "user", streamPort: 8001)
        return OpenWebifClient(profile: profile, password: "runtime-only", session: session)
    }

    @Test func readsHDDListFromBoxInfoAndPreservesReceiverDisplayStrings() async throws {
        let api = client(json: #"{"hdd":[{"model":"Disk A","labelled_capacity":"2 TB","capacity":"2.0 TB","free":"512.0 GB","mount":"/media/hdd/"},{"model":"USB","capacity":"128 GB","free":"No mount","mount":""}]}"#)
        let storage = try await api.storageInfo()
        #expect(storage.count == 2)
        #expect(storage[0].model == "Disk A")
        #expect(StorageURLProtocol.state.lastPath() == "/api/boxinfo")
        #expect(storage[0].capacity == "2.0 TB")
        #expect(storage[0].free == "512.0 GB")
        #expect(storage[0].mountPath == "/media/hdd")
        #expect(storage[1].mountPath == nil)
        #expect(storage[1].free == nil)
    }

    @Test func fallsBackToAboutOnOlderOpenWebif() async throws {
        let api = client(json: #"{"info":{"hdd":[{"model":"Disk","mount":"/media/storage","capacity":"1 TB","free":"400 GB"}]}}"#, boxInfoMissing: true)
        let disks = try await api.storageInfo()
        #expect(StorageURLProtocol.state.lastPath() == "/api/about")
        #expect(disks.first?.free == "400 GB")
    }

    @Test func associatesOnlyPathsInsideReportedMount() throws {
        let disk = try #require(ReceiverStorage.decodeList(from: ["hdd": [
            ["model": "Disk", "mount": "/media/hdd/"]
        ]]).first)
        #expect(disk.containsRecordingDirectory("/media/hdd/movie/"))
        #expect(disk.containsRecordingDirectory("/media/hdd"))
        #expect(!disk.containsRecordingDirectory("/media/hdd2/movie/"))
        #expect(!disk.containsRecordingDirectory("relative/movie/"))
        #expect(!disk.containsRecordingDirectory(nil))
    }

    @Test func rejectsMissingStorageShapeAndMapsAuthenticationFailure() async {
        let malformed = client(json: #"{"model":"Receiver"}"#)
        await #expect(throws: AtlasFailure.invalidResponse) { try await malformed.storageInfo() }
        let unauthorized = client(status: 401, json: #"{"hdd":[]}"#)
        await #expect(throws: AtlasFailure.unauthorized) { try await unauthorized.storageInfo() }
    }
}
