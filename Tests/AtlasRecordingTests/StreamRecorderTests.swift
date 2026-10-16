import Foundation
import Testing
@testable import AtlasRecording

private struct FixtureReply: Sendable {
    var status: Int = 200
    var contentType: String? = "video/mp2t"
    var chunks: [Data] = []
    var suspendAfterChunks = false
    var requiresBasicAuth = false
    var previousFailureCount = 0
    var failAfterChunks = false
}

private final class FixtureState: @unchecked Sendable {
    static let shared = FixtureState()
    private let lock = NSLock()
    private var current = FixtureReply()
    private var requests: [URLRequest] = []
    private var challengeCredentials: [(String?, String?)] = []

    func configure(_ reply: FixtureReply) {
        lock.lock(); defer { lock.unlock() }
        current = reply
        requests = []
        challengeCredentials = []
    }

    func snapshot() -> (FixtureReply, [URLRequest]) {
        lock.lock(); defer { lock.unlock() }
        return (current, requests)
    }

    func received(_ request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        requests.append(request)
    }

    func receivedChallengeCredential(_ credential: URLCredential) {
        lock.lock(); defer { lock.unlock() }
        challengeCredentials.append((credential.user, credential.password))
    }

    func credentialsSnapshot() -> [(String?, String?)] {
        lock.lock(); defer { lock.unlock() }
        return challengeCredentials
    }
}

private final class FixtureChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    private let onCredential: @Sendable (URLCredential) -> Void
    private let onCancel: @Sendable () -> Void

    init(onCredential: @escaping @Sendable (URLCredential) -> Void,
         onCancel: @escaping @Sendable () -> Void) {
        self.onCredential = onCredential
        self.onCancel = onCancel
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        onCredential(credential)
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        onCancel()
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        onCancel()
    }
}

private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    private var challengeSender: FixtureChallengeSender?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        FixtureState.shared.received(request)
        let (reply, _) = FixtureState.shared.snapshot()
        if reply.requiresBasicAuth,
           request.value(forHTTPHeaderField: "Authorization") == nil,
           let url = request.url {
            let sender = FixtureChallengeSender(onCredential: { [weak self] credential in
                FixtureState.shared.receivedChallengeCredential(credential)
                self?.send(reply)
            }, onCancel: { [weak self] in
                guard let self else { return }
                self.client?.urlProtocol(self, didFailWithError: URLError(.userAuthenticationRequired))
            })
            challengeSender = sender
            let protectionSpace = URLProtectionSpace(host: url.host ?? "receiver.test",
                                                     port: url.port ?? 80,
                                                     protocol: url.scheme,
                                                     realm: "synthetic fixture",
                                                     authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            let challenge = URLAuthenticationChallenge(protectionSpace: protectionSpace,
                                                        proposedCredential: nil,
                                                        previousFailureCount: reply.previousFailureCount,
                                                        failureResponse: nil,
                                                        error: nil,
                                                        sender: sender)
            client?.urlProtocol(self, didReceive: challenge)
            return
        }
        send(reply)
    }

    private func send(_ reply: FixtureReply) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status,
                                             httpVersion: "HTTP/1.1",
                                             headerFields: reply.contentType.map { ["Content-Type": $0] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in reply.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        if reply.failAfterChunks {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            }
        } else if !reply.suspendAfterChunks {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() { }
}

@Suite("MPEG-TS stream recording", .serialized)
struct StreamRecorderTests {
    private func transport(_ packetCount: Int = 5) -> Data {
        var result = Data()
        for packet in 0..<packetCount {
            result.append(0x47)
            result.append(contentsOf: (1..<188).map { UInt8((packet + $0) & 0xff) })
        }
        return result
    }

    private func fixture(_ reply: FixtureReply) -> (URL, URL, URLSessionConfiguration) {
        FixtureState.shared.configure(reply)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (URL(string: "http://receiver.test:8001/1:0:1:synthetic")!, directory.appendingPathComponent("capture.ts"), configuration)
    }

    @Test func writesChunkedTransportBytesExactlyAndReportsProgress() async throws {
        let stream = transport()
        let (url, target, configuration) = fixture(FixtureReply(chunks: [stream.prefix(117), stream.dropFirst(117).prefix(700), stream.dropFirst(817)]))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        let values = try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { _ in }
        #expect(values == Int64(stream.count))
        #expect(try Data(contentsOf: target) == stream)
    }

    @Test func cancellationKeepsValidPartialCaptureAndReturnsItsLength() async throws {
        let stream = transport(4)
        let (url, target, configuration) = fixture(FixtureReply(chunks: [stream], suspendAfterChunks: true))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        let progress = AsyncStream<Int64>.makeStream()
        let task = Task {
            try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { progress.continuation.yield($0) }
        }
        for await count in progress.stream {
            if count > 0 { task.cancel(); break }
        }
        progress.continuation.finish()
        let captured = try await task.value
        #expect(captured == Int64(stream.count))
        #expect(try Data(contentsOf: target) == stream)
    }

    @Test func networkFailureKeepsValidPartialCaptureAndReturnsGenericError() async throws {
        let stream = transport(4)
        let (url, target, configuration) = fixture(FixtureReply(chunks: [stream], failAfterChunks: true))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        await #expect(throws: StreamRecorder.RecordingError.transferFailed) {
            try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { _ in }
        }
        #expect(try Data(contentsOf: target) == stream)
    }

    @Test func rejectsPlaylistAndInvalidSyncBytesAndRemovesOwnedEmptyFile() async throws {
        let playlist = Data("#EXTM3U\nhttp://receiver.test/live".utf8)
        let (url, target, configuration) = fixture(FixtureReply(contentType: "application/vnd.apple.mpegurl", chunks: [playlist]))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        await #expect(throws: StreamRecorder.RecordingError.invalidStream) {
            try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: target.path))

        let broken = Data(repeating: 0, count: 3 * 188)
        FixtureState.shared.configure(FixtureReply(chunks: [broken]))
        await #expect(throws: StreamRecorder.RecordingError.invalidStream) {
            try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func neverOverwritesExistingDestination() async throws {
        let (url, target, configuration) = fixture(FixtureReply(chunks: [transport()]))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        let original = Data("keep-existing".utf8)
        try original.write(to: target)
        await #expect(throws: StreamRecorder.RecordingError.transferFailed) {
            try await StreamRecorder.record(url: url, to: target, username: "", password: "", configuration: configuration) { _ in }
        }
        #expect(try Data(contentsOf: target) == original)
    }

    @Test func sendsNoURLCredentialsOrPreemptiveAuthorization() async throws {
        let (url, target, configuration) = fixture(FixtureReply(chunks: [transport()]))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        _ = try await StreamRecorder.record(url: url, to: target, username: "fixture-user", password: "fixture-secret", configuration: configuration) { _ in }
        let requests = FixtureState.shared.snapshot().1
        #expect(requests.count == 1)
        #expect(requests[0].url?.user == nil)
        #expect(requests[0].url?.password == nil)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func sendsBasicCredentialsOnlyAfterSameOriginChallenge() async throws {
        let (url, target, configuration) = fixture(FixtureReply(chunks: [transport()], requiresBasicAuth: true))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        _ = try await StreamRecorder.record(url: url, to: target, username: "fixture-user", password: "fixture-secret", configuration: configuration) { _ in }
        let requests = FixtureState.shared.snapshot().1
        #expect(requests.count == 1)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == nil)
        let credentials = FixtureState.shared.credentialsSnapshot()
        #expect(credentials.count == 1)
        #expect(credentials[0].0 == "fixture-user")
        #expect(credentials[0].1 == "fixture-secret")
    }

    @Test func cancelsRepeatedBasicChallenge() async throws {
        let (url, target, configuration) = fixture(FixtureReply(chunks: [transport()], requiresBasicAuth: true, previousFailureCount: 1))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        await #expect(throws: StreamRecorder.RecordingError.transferFailed) {
            try await StreamRecorder.record(url: url, to: target, username: "fixture-user", password: "fixture-secret", configuration: configuration) { _ in }
        }
        #expect(FixtureState.shared.credentialsSnapshot().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func rejectsURLCredentialsAndNonHTTPAddressesBeforeCreatingFile() async throws {
        let (_, target, configuration) = fixture(FixtureReply(chunks: [transport()]))
        defer { try? FileManager.default.removeItem(at: target.deletingLastPathComponent()) }
        let credentialed = URL(string: "http://user:pass@receiver.test:8001/live")!
        await #expect(throws: StreamRecorder.RecordingError.invalidAddress) {
            try await StreamRecorder.record(url: credentialed, to: target, username: "", password: "", configuration: configuration) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }
}
