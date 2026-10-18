#if !SWIFT_PACKAGE
import Foundation
import Testing
import os
import AtlasCore
@testable import AtlasReceiver

private final class MetadataProtocol: URLProtocol, @unchecked Sendable {
    static let failVerification = OSAllocatedUnfairLock(initialState: false)
    static let failuresRemaining = OSAllocatedUnfairLock(initialState: 0)
    static let verificationRequests = OSAllocatedUnfairLock(initialState: 0)
    static let totalRequests = OSAllocatedUnfairLock(initialState: 0)
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.totalRequests.withLock { $0 += 1 }
        if request.url?.path == "/api/about" {
            Self.verificationRequests.withLock { $0 += 1 }
            let transientFailure = Self.failuresRemaining.withLock { remaining in
                guard remaining > 0 else { return false }
                remaining -= 1
                return true
            }
            if transientFailure || Self.failVerification.withLock({ $0 }) {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
        }
        let json: String
        switch request.url?.path {
        case "/api/about": json = #"{"info":{"model":"Synthetic","imagedistro":"Fixture"}}"#
        case "/api/bouquets": json = #"{"bouquets":[["fixture","Fixture"]]}"#
        case "/api/getservices": json = #"{"services":[{"servicereference":"fixture-1","servicename":"News"}]}"#
        default:
            let begin = Int(Date().timeIntervalSince1970)
            json = "{\"events\":[{\"begin_timestamp\":\(begin),\"duration_sec\":3600,\"title\":\"Fixture programme\"}]}"
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

@Suite("Receiver metadata recovery", .serialized)
@MainActor
struct ChannelStoreTests {
    private func store() -> ChannelStore {
        MetadataProtocol.failuresRemaining.withLock { $0 = 0 }
        MetadataProtocol.verificationRequests.withLock { $0 = 0 }
        MetadataProtocol.totalRequests.withLock { $0 = 0 }
        let value = ChannelStore { profile, password in
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MetadataProtocol.self]
            return OpenWebifClient(profile: profile, password: password, session: URLSession(configuration: config))
        }
        value.startupRetryDelays = [.zero, .zero]
        return value
    }

    @Test func disabledStartupDoesNotRequestMetadataButManualRefreshWorks() async {
        MetadataProtocol.failVerification.withLock { $0 = false }
        let channels = store()
        await channels.connect(ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "", loadMetadata: false)
        #expect(MetadataProtocol.totalRequests.withLock { $0 } == 0)
        #expect(channels.channels.isEmpty)
        #expect(channels.client != nil)
        await channels.refresh()
        #expect(channels.channels.count == 1)
    }

    @Test func startupRetriesTransientFailureAutomatically() async {
        MetadataProtocol.failVerification.withLock { $0 = false }
        let channels = store()
        MetadataProtocol.failuresRemaining.withLock { $0 = 1 }
        await channels.connect(ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "")
        #expect(MetadataProtocol.verificationRequests.withLock { $0 } == 2)
        #expect(channels.error == nil)
        #expect(channels.channels.count == 1)
    }

    @Test func startupRetryLimitIsThreeAttempts() async {
        MetadataProtocol.failVerification.withLock { $0 = true }
        let channels = store()
        await channels.connect(ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "")
        #expect(MetadataProtocol.verificationRequests.withLock { $0 } == 3)
        #expect(channels.error != nil)
        #expect(!channels.isLoading)
        MetadataProtocol.failVerification.withLock { $0 = false }
    }

    @Test func cancellingStartupStopsPendingRetry() async {
        MetadataProtocol.failVerification.withLock { $0 = true }
        let channels = store()
        channels.startupRetryDelays = [.seconds(10)]
        let task = Task {
            await channels.connect(ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "")
        }
        let deadline = ContinuousClock.now + .seconds(2)
        while channels.error == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(channels.error != nil)
        task.cancel()
        await task.value
        #expect(MetadataProtocol.verificationRequests.withLock { $0 } == 1)
        #expect(!channels.isLoading)
        MetadataProtocol.failVerification.withLock { $0 = false }
    }

    @Test func retryFailedMetadataLoadsChannelsAndGuide() async {
        MetadataProtocol.failVerification.withLock { $0 = true }
        let channels = store()
        let profile = ReceiverProfile(name: "Fixture", address: "receiver.test")
        await channels.connect(profile, password: "")
        #expect(channels.error != nil)
        #expect(channels.channels.isEmpty)
        let originalClient = channels.client
        MetadataProtocol.failVerification.withLock { $0 = false }
        await channels.refresh()
        #expect(channels.error == nil)
        #expect(channels.client === originalClient)
        #expect(channels.channels.map(\.id) == ["fixture-1"])
        let guide = GuideStore()
        await guide.load(channels: channels.channels, client: channels.client)
        #expect(guide.events["fixture-1"]?.first?.title == "Fixture programme")
        #expect(guide.errors.isEmpty)
    }

    @Test func refreshSameChannelsChangesQueryRevisionAndFailureKeepsData() async {
        MetadataProtocol.failVerification.withLock { $0 = false }
        let channels = store()
        await channels.connect(ReceiverProfile(name: "Fixture", address: "receiver.test"), password: "")
        let revision = channels.metadataRevision
        let values = channels.channels
        await channels.refresh()
        #expect(channels.channels == values)
        #expect(channels.metadataRevision > revision)
        MetadataProtocol.failVerification.withLock { $0 = true }
        await channels.refresh()
        #expect(channels.error != nil)
        #expect(channels.channels == values)
        #expect(!channels.isLoading)
        MetadataProtocol.failVerification.withLock { $0 = false }
    }
}
#endif
