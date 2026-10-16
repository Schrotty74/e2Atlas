import AVFoundation
import AppKit
import AtlasCore
import Foundation
import Testing
import VLCKit
@testable import AtlasPlayback

@Suite("Playback engine", .serialized)
@MainActor
struct PlaybackEngineTests {
    @Test("Plays a generated local video in two independent VLC slots")
    func localVideoAndIndependentSlots() async throws {
        let fixture = try await makeVideoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let first = PlaybackSlot()
        let second = PlaybackSlot()
        defer {
            first.stop()
            second.stop()
        }

        first.play(url: fixture.video, channel: testChannel("first"), username: "", password: "")
        second.play(url: fixture.video, channel: testChannel("second"), username: "", password: "")

        #expect(await waitUntil { Self.hasDecodedVideo(first) && Self.hasDecodedVideo(second) })
        #expect(await waitUntil { first.hasPresentedVideo && second.hasPresentedVideo })
        #expect(!first.isLoading)
        #expect(!second.isLoading)
        #expect(first.isMuted)
        #expect(second.isMuted)

        first.volume = 0.35
        first.isMuted = false
        #expect(first.vlcPlayer.audio?.volume == 35)
        #expect(first.vlcPlayer.audio?.isMuted == false)
        first.isMuted = true
        #expect(first.vlcPlayer.audio?.isMuted == true)
        #expect(second.isMuted)
        #expect(second.volume == 1)

        second.vlcPlayer.pause()
        #expect(await waitUntil { second.status == .paused })
        #expect(second.status == .paused)
        second.vlcPlayer.play()
        #expect(await waitUntil { second.status == .playing })

        let secondTimeBeforeStoppingPeer = second.vlcPlayer.time.intValue
        first.stop()
        #expect(first.status == .idle)
        #expect(!first.hasPresentedVideo)
        #expect(await waitUntil { second.vlcPlayer.time.intValue > secondTimeBeforeStoppingPeer })
        #expect(second.channel?.id == "second")

        try await Task.sleep(for: .milliseconds(500))
        #expect(first.status == .idle, "A late event from the stopped engine must not revive its slot.")
        #expect(Self.hasDecodedVideo(second), "Stopping one slot must leave the other engine running.")
    }

    @Test("Reports an unreadable local stream without affecting another slot")
    func missingFileFailsLocally() async throws {
        let fixture = try await makeVideoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let missingURL = fixture.directory.appendingPathComponent("missing.ts")
        let working = PlaybackSlot()
        let failing = PlaybackSlot()
        defer {
            working.stop()
            failing.stop()
        }

        working.play(url: fixture.video, channel: testChannel("working"), username: "", password: "")
        failing.play(url: missingURL, channel: testChannel("missing"), username: "", password: "")

        #expect(Self.isFailure(failing.status))
        #expect(await waitUntil { Self.hasDecodedVideo(working) })
        #expect(Self.hasDecodedVideo(working))
        #expect(failing.channel?.id == "missing")
    }

    @Test("Uses VLC for authenticated HLS instead of rejecting credentials")
    func authenticatedHLSUsesVLC() async throws {
        let slot = PlaybackSlot()
        defer { slot.stop() }
        // Loopback keeps this failure-path test offline while exercising VLC's authenticated-HLS route.
        let playlistURL = try #require(URL(string: "http://127.0.0.1:1/missing.m3u8"))
        slot.play(
            url: playlistURL,
            channel: testChannel("authenticated-hls"),
            username: "synthetic-user",
            password: "synthetic-password"
        )

        #expect(slot.avPlayer == nil)
        #expect(await waitUntil { Self.isFailure(slot.status) })
    }

    @Test("Moving fullscreen containers keeps the running VLC drawable")
    func keepsVideoOutputAcrossContainerReplacement() async throws {
        let fixture = try await makeVideoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let slot = PlaybackSlot()
        defer { slot.stop() }
        let tile = VLCVideoContainer(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        let fullscreen = VLCVideoContainer(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        tile.attach(slot.vlcVideoView)
        slot.play(url: fixture.video, channel: testChannel("fullscreen"), username: "", password: "")
        #expect(await waitUntil { Self.hasDecodedVideo(slot) })
        let before = slot.vlcPlayer.time.intValue
        for _ in 0..<3 {
            fullscreen.attach(slot.vlcVideoView)
            tile.detach()
            #expect(slot.vlcVideoView.superview === fullscreen)
            #expect((slot.vlcPlayer.drawable as? VLCVideoView) === slot.vlcVideoView)
            tile.attach(slot.vlcVideoView)
            fullscreen.detach()
            #expect(slot.vlcVideoView.superview === tile)
        }
        #expect(await waitUntil { slot.vlcPlayer.time.intValue > before })
        #expect(Self.hasDecodedVideo(slot))
        #expect(slot.channel?.id == "fullscreen")
    }

    @Test("Swapping main and secondary video preserves both running engines")
    func swappingRunningPlayersKeepsMediaAndVideoOutput() async throws {
        let fixture = try await makeVideoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let first = PlaybackSlot()
        let second = PlaybackSlot()
        defer { first.stop(); second.stop() }
        let main = VLCVideoContainer(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        let small = VLCVideoContainer(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        main.attach(first.vlcVideoView)
        small.attach(second.vlcVideoView)
        first.play(url: fixture.video, channel: testChannel("main"), username: "", password: "")
        second.play(url: fixture.video, channel: testChannel("small"), username: "", password: "")
        #expect(await waitUntil { Self.hasDecodedVideo(first) && Self.hasDecodedVideo(second) })
        let firstMedia = first.vlcPlayer.media
        let secondMedia = second.vlcPlayer.media
        let firstTime = first.vlcPlayer.time.intValue
        let secondTime = second.vlcPlayer.time.intValue
        var arrangement = PlaybackArrangement(slots: [first, second])
        first.volume = 0.35
        first.isMuted = false
        for _ in 0..<3 {
            arrangement.swapWithMain(1)
            main.attach(arrangement.slots[0].vlcVideoView)
            small.attach(arrangement.slots[1].vlcVideoView)
            #expect(arrangement.slots[0].vlcVideoView.superview === main)
            #expect(arrangement.slots[1].vlcVideoView.superview === small)
        }
        #expect(first.vlcPlayer.media === firstMedia)
        #expect(second.vlcPlayer.media === secondMedia)
        #expect(first.channel?.id == "main")
        #expect(second.channel?.id == "small")
        #expect(arrangement.slots[arrangement.audibleIndex] === first)
        #expect(first.vlcPlayer.audio?.isMuted == false)
        #expect(second.vlcPlayer.audio?.isMuted == true)
        #expect(first.vlcPlayer.audio?.volume == 35)
        #expect(await waitUntil { first.vlcPlayer.time.intValue > firstTime && second.vlcPlayer.time.intValue > secondTime })
    }

    @Test("AVPlayer retains volume and mute across stream replacement")
    func nativeVolumeAcrossStreams() throws {
        let slot = PlaybackSlot()
        defer { slot.stop() }
        let url = try #require(URL(string: "http://127.0.0.1:1/synthetic.m3u8"))
        slot.volume = 0.42
        slot.isMuted = false
        slot.play(url: url, channel: testChannel("native-first"), username: "", password: "")
        let first = try #require(slot.avPlayer)
        #expect(abs(first.volume - 0.42) < 0.001)
        #expect(!first.isMuted)
        slot.isMuted = true
        slot.volume = 0.27
        slot.play(url: url, channel: testChannel("native-second"), username: "", password: "")
        let second = try #require(slot.avPlayer)
        #expect(second !== first)
        #expect(second.isMuted)
        #expect(abs(second.volume - 0.27) < 0.001)
        slot.volume = .nan
        #expect(abs(second.volume - 0.27) < 0.001)
        slot.volume = 2
        #expect(second.volume == 1)
        slot.volume = -1
        #expect(second.volume == 0)
    }

    private static func hasDecodedVideo(_ slot: PlaybackSlot) -> Bool {
        slot.vlcPlayer.hasVideoOut && slot.vlcPlayer.time.intValue > 0
    }

    private static func isFailure(_ status: PlaybackStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }

    private func testChannel(_ id: String) -> Channel {
        Channel(id: id, name: "Synthetic \(id)")
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(10),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() && clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(100))
    }
    return condition()
}

@MainActor
private func makeVideoFixture() async throws -> (directory: URL, video: URL) {
    let directory = try makeEmptyFixtureDirectory()
    let video = directory.appendingPathComponent("synthetic.mp4")
    let writer = try AVAssetWriter(outputURL: video, fileType: .mp4)
    let width = 64
    let height = 64
    let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
    )
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
    )
    guard writer.canAdd(input) else { throw FixtureError.cannotAddWriterInput }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? FixtureError.cannotStartWriter }
    writer.startSession(atSourceTime: .zero)

    for index in 0..<180 {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(for: .milliseconds(10))
        }
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw FixtureError.cannotCreatePixelBuffer
        }
        var optionalBuffer: CVPixelBuffer?
        let result = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pixelBufferPool,
            &optionalBuffer
        )
        guard result == kCVReturnSuccess, let buffer = optionalBuffer else {
            throw FixtureError.cannotCreatePixelBuffer
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            baseAddress.initializeMemory(
                as: UInt8.self,
                repeating: UInt8(40 + (index % 3) * 60),
                count: CVPixelBufferGetBytesPerRow(buffer) * height
            )
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else {
            throw writer.error ?? FixtureError.cannotAppendFrame
        }
    }

    input.markAsFinished()
    await withCheckedContinuation { continuation in
        writer.finishWriting { continuation.resume() }
    }
    guard writer.status == .completed else { throw writer.error ?? FixtureError.cannotFinishWriter }
    return (directory, video)
}

@MainActor
private func makeEmptyFixtureDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("e2Atlas-PlaybackTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private enum FixtureError: Error {
    case cannotAddWriterInput
    case cannotStartWriter
    case cannotCreatePixelBuffer
    case cannotAppendFrame
    case cannotFinishWriter
}


@Suite("Loading over receiver video")
@MainActor
struct PlaybackLoadingTests {
    @Test func bufferingDoesNotCoverAlreadyPresentedVideo() {
        let slot = PlaybackSlot()
        defer { slot.stop() }
        slot.updateVLCPlayback(state: .opening, displayedPictures: 0)
        #expect(slot.isLoading)
        slot.updateVLCPlayback(state: .buffering, displayedPictures: 1)
        #expect(slot.status == .connecting)
        #expect(slot.hasPresentedVideo)
        #expect(!slot.isLoading)
        // A temporarily absent statistics sample must not restore the overlay.
        slot.updateVLCPlayback(state: .buffering, displayedPictures: 0)
        #expect(!slot.isLoading)
        slot.updateVLCPlayback(state: .error, displayedPictures: 0)
        #expect(slot.status == .failed("Der Videostream konnte nicht geöffnet werden."))
        #expect(!slot.isLoading)
    }

    @Test func senderChangeAndStopResetPresentationEvidence() throws {
        let slot = PlaybackSlot()
        defer { slot.stop() }
        slot.updateVLCPlayback(state: .buffering, displayedPictures: 12)
        #expect(!slot.isLoading)
        // Loopback gives the new media an independent, offline startup phase.
        let url = try #require(URL(string: "http://127.0.0.1:1/synthetic.ts"))
        slot.play(url: url, channel: Channel(id: "new", name: "Synthetic"), username: "", password: "")
        #expect(!slot.hasPresentedVideo)
        #expect(slot.isLoading)
        slot.stop()
        #expect(!slot.hasPresentedVideo)
        #expect(!slot.isLoading)
    }

    @Test func eachMultiviewTileTracksItsOwnFirstPicture() {
        let visible = PlaybackSlot()
        let waiting = PlaybackSlot()
        defer { visible.stop(); waiting.stop() }
        visible.updateVLCPlayback(state: .buffering, displayedPictures: 3)
        waiting.updateVLCPlayback(state: .buffering, displayedPictures: 0)
        #expect(!visible.isLoading)
        #expect(waiting.isLoading)
        visible.stop()
        #expect(waiting.isLoading)
    }
}
