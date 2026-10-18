import AVFoundation
import AtlasCore
import Observation
import os
import SwiftUI

#if canImport(VLCKit)
import VLCKit
#endif

public enum PlaybackStatus: Equatable, Sendable {
    case idle
    case connecting
    case playing
    case paused
    case failed(String)
}

/// State and playback engine for one independent multiview tile.
@MainActor
@Observable
public final class PlaybackSlot: Identifiable {
    public let id: UUID
    public private(set) var channel: Channel?
    public private(set) var status: PlaybackStatus = .idle
    public private(set) var hasPresentedVideo = false
    public var isLoading: Bool { status == .connecting && !hasPresentedVideo }
    public var isMuted = true {
        didSet { applyMuteState() }
    }
    private var storedVolume: Double = 1
    /// Normalized playback volume, independent of muting and media replacement.
    public var volume: Double {
        get { storedVolume }
        set {
            guard newValue.isFinite else { return }
            storedVolume = min(max(newValue, 0), 1)
            applyVolume()
        }
    }

    private(set) var avPlayer: AVPlayer?
    #if canImport(VLCKit)
    let vlcPlayer = VLCMediaPlayer()
    @ObservationIgnored let vlcVideoView = VLCVideoView(frame: .zero)
    #endif

    private var avPlayerItemObservation: NSKeyValueObservation?
    private var avTimeControlObservation: NSKeyValueObservation?
    private var playbackGeneration = UUID()
    @ObservationIgnored private var lastVideoProgress: ContinuousClock.Instant?
    @ObservationIgnored private var lastDisplayedPictures: Int32 = 0
    private static let recoveryLogger = Logger(subsystem: "io.github.schrotty74.e2atlas.playback", category: "Recovery")
    @ObservationIgnored private var recoveryTask: Task<Void, Never>?
    @ObservationIgnored var recoveryPollInterval: Duration = .seconds(1)
    @ObservationIgnored var reconnectBackoff: [Duration] = [.seconds(2), .seconds(4), .seconds(6)]
    @ObservationIgnored var recoveryConnectionTimeout: TimeInterval = 25
    public private(set) var reconnectAttempt = 0
    public private(set) var isReconnecting = false
    #if canImport(VLCKit)
    private var vlcStateTask: Task<Void, Never>?
    #endif

    public init(id: UUID = UUID()) {
        self.id = id
        avPlayer = nil
        #if canImport(VLCKit)
        // libVLC's active video output must keep the same drawable when SwiftUI
        // replaces a tile with fullscreen content or updates the window layout.
        vlcPlayer.drawable = vlcVideoView
        vlcPlayer.audio?.isMuted = true
        #endif
    }

    isolated deinit {
        recoveryTask?.cancel()
        stopEngine()
    }

    /// Starts playback. Credentials are passed to the media engine separately and never added to the URL.
    public func play(url: URL, channel: Channel, username: String, password: String) {
        recoveryTask?.cancel()
        reconnectAttempt = 0
        isReconnecting = false
        startPlayback(url: url, channel: channel, username: username, password: password)
        if !url.isFileURL { monitorRecovery(url: url, channel: channel, username: username, password: password) }
    }

    private func startPlayback(url: URL, channel: Channel, username: String, password: String) {
        stopEngine()
        let generation = UUID()
        playbackGeneration = generation
        self.channel = channel
        hasPresentedVideo = false
        lastVideoProgress = nil
        lastDisplayedPictures = 0
        status = .connecting

        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
            status = .failed("Der Videostream konnte nicht geöffnet werden.")
            return
        }

        if Self.isHLSURL(url) && username.isEmpty && password.isEmpty {
            let player = AVPlayer()
            player.isMuted = isMuted
            player.volume = Float(volume)
            let item = AVPlayerItem(url: url)
            avPlayerItemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.playbackGeneration == generation else { return }
                    if item.status == .failed {
                        self.status = .failed("Der Videostream konnte nicht geöffnet werden.")
                    } else if item.status == .readyToPlay {
                        self.status = .playing
                    }
                }
            }
            avTimeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.playbackGeneration == generation else { return }
                    if player.timeControlStatus == .playing {
                        self.status = .playing
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            avPlayer = player
            player.play()
        } else {
            #if canImport(VLCKit)
            let media = VLCMedia(url: url)
            // Prefer Apple's hardware decoder when the codec and Mac support it.
            // libVLC retains its software fallback for unsupported streams.
            media.addOption(":videotoolbox=1")
            if !username.isEmpty {
                media.addOption(":http-user=\(username)")
            }
            if !password.isEmpty {
                media.addOption(":http-pwd=\(password)")
            }
            vlcPlayer.media = media
            vlcPlayer.audio?.isMuted = isMuted
            // Avoid changing engine volume during failed-output teardown.
            // The stored volume is applied once playback or video output is ready.
            monitorVLCState(generation: generation)
            vlcPlayer.play()
            #else
            let message = Self.isHLSURL(url)
                ? "Für HLS-Streams mit Anmeldung ist die Wiedergabekomponente VLC erforderlich."
                : "Für diesen Receiverstream ist die Wiedergabekomponente VLC erforderlich."
            status = .failed(message)
            #endif
        }
    }

    public func stop() {
        cancelReconnect()
        playbackGeneration = UUID()
        stopEngine()
        isMuted = true
        channel = nil
        hasPresentedVideo = false
        status = .idle
    }

    /// Cancels pending retries while leaving a currently working stream alone.
    public func cancelReconnect() {
        recoveryTask?.cancel()
        recoveryTask = nil
        isReconnecting = false
    }

    private func monitorRecovery(url: URL, channel: Channel, username: String, password: String) {
        recoveryTask = Task { @MainActor [weak self] in
            var connectingSince = ContinuousClock.now
            var stableSince: ContinuousClock.Instant?
            while !Task.isCancelled {
                do { try await Task.sleep(for: self?.recoveryPollInterval ?? .seconds(1)) } catch { return }
                guard let self, self.channel == channel else { return }
                let failed: Bool
                let reason: String
                switch self.status {
                case .failed: failed = true; reason = "engine-error"
                case .idle: failed = true; reason = "engine-ended"
                case .connecting:
                    failed = self.recoveryConnectionHasTimedOut(since: connectingSince)
                    reason = "no-video-progress"
                case .playing, .paused:
                    connectingSince = ContinuousClock.now
                    if stableSince == nil { stableSince = ContinuousClock.now }
                    if let stableSince, stableSince.duration(to: .now) >= .seconds(30) { self.reconnectAttempt = 0 }
                    self.isReconnecting = false
                    continue
                }
                stableSince = nil
                guard failed else { continue }
                guard self.reconnectAttempt < self.reconnectBackoff.count else {
                    self.playbackGeneration = UUID()
                    self.stopEngine()
                    self.hasPresentedVideo = false
                    self.isReconnecting = false
                    self.status = .failed("Keine Verbindung nach drei Versuchen. Bitte den Sender erneut wählen.")
                    return
                }
                self.reconnectAttempt += 1
                Self.recoveryLogger.notice("Retry reason: \(reason, privacy: .public); attempt: \(self.reconnectAttempt, privacy: .public); video presented: \(self.hasPresentedVideo, privacy: .public)")
                self.isReconnecting = true
                do { try await Task.sleep(for: self.reconnectBackoff[self.reconnectAttempt - 1]) } catch { return }
                guard !Task.isCancelled, self.channel == channel else { return }
                self.startPlayback(url: url, channel: channel, username: username, password: password)
                connectingSince = ContinuousClock.now
            }
        }
    }

    // VLC can remain in buffering while decoding and displaying live TV.
    // Only a lack of new pictures may expire this connection deadline.
    func recoveryConnectionHasTimedOut(since start: ContinuousClock.Instant,
                                       now: ContinuousClock.Instant = .now) -> Bool {
        let activity = max(start, lastVideoProgress ?? start)
        return activity.duration(to: now) >= .seconds(recoveryConnectionTimeout)
    }

    private func stopEngine() {
        avPlayer?.pause()
        avPlayer?.replaceCurrentItem(with: nil)
        avPlayer = nil
        avPlayerItemObservation = nil
        avTimeControlObservation = nil
        #if canImport(VLCKit)
        vlcStateTask?.cancel()
        vlcStateTask = nil
        vlcPlayer.stop()
        vlcPlayer.media = nil
        #endif
    }

    #if canImport(VLCKit)
    // VLC may report buffering after it has already displayed video. Keep this
    // per-media evidence separate from transport state so it cannot obscure TV.
    func updateVLCPlayback(state: VLCMediaPlayerState, displayedPictures: Int32,
                           at now: ContinuousClock.Instant = .now) {
        if displayedPictures > 0 {
            hasPresentedVideo = true
            if displayedPictures != lastDisplayedPictures {
                lastVideoProgress = now
                lastDisplayedPictures = displayedPictures
            }
        }
        switch state {
        case .playing:
            if status != .playing { status = .playing; applyMuteState(); applyVolume() }
        case .paused:
            status = .paused
        case .error:
            status = .failed("Der Videostream konnte nicht geöffnet werden.")
        case .opening, .buffering, .esAdded:
            status = .connecting
        case .ended:
            status = .idle
        case .stopped:
            break
        @unknown default:
            break
        }
    }

    private func monitorVLCState(generation: UUID) {
        vlcStateTask = Task { @MainActor [weak self] in
            let startupDeadline = ContinuousClock.now + .seconds(5)
            while !Task.isCancelled {
                guard self?.playbackGeneration == generation,
                      let state = self?.vlcPlayer.state else { return }

                if self?.vlcPlayer.media?.state == .error {
                    self?.status = .failed("Der Videostream konnte nicht geöffnet werden.")
                    return
                }

                self?.updateVLCPlayback(
                    state: state,
                    displayedPictures: self?.vlcPlayer.media?.statistics.displayedPictures ?? 0
                )
                if state == .error || state == .ended { return }
                if state == .stopped && ContinuousClock.now >= startupDeadline {
                    self?.status = .failed("Der Videostream konnte nicht geöffnet werden.")
                    return
                }

                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
            }
        }
    }
    #endif

    private func applyMuteState() {
        if let avPlayer, avPlayer.isMuted != isMuted { avPlayer.isMuted = isMuted }
        #if canImport(VLCKit)
        // Rebuffering may repeatedly report playing without replacing the output.
        // Leave an already correct audio output alone.
        if let audio = vlcPlayer.audio, audio.isMuted != isMuted { audio.isMuted = isMuted }
        #endif
    }

    private func applyVolume() {
        let nativeVolume = Float(volume)
        if let avPlayer, avPlayer.volume != nativeVolume { avPlayer.volume = nativeVolume }
        #if canImport(VLCKit)
        if status == .playing || status == .paused || hasPresentedVideo {
            let desiredVolume = Int32((volume * 100).rounded())
            if let audio = vlcPlayer.audio, audio.volume != desiredVolume { audio.volume = desiredVolume }
        }
        #endif
    }

    nonisolated public static func isHLSURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "m3u8"
    }
}

/// A native video surface for a single playback slot.
@MainActor
public struct PlaybackSurface: View {
    private let slot: PlaybackSlot

    public init(slot: PlaybackSlot) {
        self.slot = slot
    }

    public var body: some View {
        ZStack {
            Color.black
            #if canImport(VLCKit)
            if let player = slot.avPlayer {
                AVPlaybackSurface(player: player)
            } else {
                VLCPlaybackSurface(slot: slot).id(slot.id)
            }
            #else
            if let player = slot.avPlayer {
                AVPlaybackSurface(player: player)
            }
            #endif
            if case let .failed(message) = slot.status {
                Text(LocalizedStringKey(message))
                    .font(.callout)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if slot.isLoading {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Video wird geladen")
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .accessibilityLabel(slot.channel?.name ?? "Video")
    }
}

private struct AVPlaybackSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.wantsLayer = true
        (view.layer as? AVPlayerLayer)?.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerLayerView, context: Context) {
        (view.layer as? AVPlayerLayer)?.player = player
    }
}

private final class AVPlayerLayerView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        return playerLayer
    }
}

#if canImport(VLCKit)
private struct VLCPlaybackSurface: NSViewRepresentable {
    let slot: PlaybackSlot

    func makeNSView(context: Context) -> VLCVideoContainer {
        let view = VLCVideoContainer()
        view.attach(slot.vlcVideoView)
        return view
    }

    func updateNSView(_ view: VLCVideoContainer, context: Context) {
        // The slot identity is fixed for this wrapper. A late update of the old
        // wrapper must not steal the drawable back from its fullscreen owner.
    }

    static func dismantleNSView(_ nsView: VLCVideoContainer, coordinator: ()) {
        nsView.detach()
    }
}

/// SwiftUI owns this wrapper. The slot owns the native VLC drawable inside it.
final class VLCVideoContainer: NSView {
    private weak var videoView: VLCVideoView?

    override func layout() {
        super.layout()
        if videoView?.superview === self { videoView?.frame = bounds }
    }

    func attach(_ videoView: VLCVideoView) {
        self.videoView = videoView
        guard videoView.superview !== self else { return }
        videoView.removeFromSuperview()
        videoView.frame = bounds
        videoView.autoresizingMask = [.width, .height]
        addSubview(videoView)
    }

    func detach() {
        // Dismantling the old wrapper must not detach a drawable already moved
        // into the new fullscreen/tile wrapper.
        if videoView?.superview === self { videoView?.removeFromSuperview() }
        videoView = nil
    }
}
#endif
