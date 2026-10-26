import Foundation
import Observation
import AtlasCore
import AtlasPlayback
import AtlasReceiver

@MainActor @Observable
final class PlaybackStore {
    private var arrangement = PlaybackArrangement(slots: (0..<4).map { _ in PlaybackSlot() })
    var slots: [PlaybackSlot] { arrangement.slots }
    var targetIndex: Int {
        get { arrangement.targetIndex }
        set { arrangement.targetIndex = newValue }
    }
    private(set) var audibleIndex: Int {
        get { arrangement.audibleIndex }
        set { arrangement.audibleIndex = newValue }
    }
    private(set) var isAudioMuted = false
    private(set) var volume: Double = 1
    @ObservationIgnored private var lastAudibleVolume: Double = 1
    var isMultiview = false
    var visibleCount = 4
    var error: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var pendingPlay: [UUID: UUID] = [:]
    @ObservationIgnored private var restoreGeneration = UUID()
    @ObservationIgnored var restoreStartupTimeout: Duration = .seconds(8)

    init() { applyAudio() }

    func swapWithMain(_ index: Int) {
        cancelRestore()
        guard isMultiview, index > 0, index < visibleCount,
              slots.indices.contains(index), slots[index].channel != nil else { return }
        arrangement.swapWithMain(index)
    }

    func selectAudio(_ index: Int) {
        cancelRestore()
        guard slots.indices.contains(index) else { return }
        audibleIndex = index
        applyAudio()
    }

    func toggleAudio(_ index: Int) {
        cancelRestore()
        guard slots.indices.contains(index) else { return }
        if volume == 0 {
            audibleIndex = index
            volume = lastAudibleVolume
            isAudioMuted = false
        } else if audibleIndex != index {
            audibleIndex = index
            isAudioMuted = false
        } else {
            isAudioMuted.toggle()
        }
        applyAudio()
    }

    func setVolume(_ value: Double) {
        cancelRestore()
        guard value.isFinite else { return }
        volume = min(max(value, 0), 1)
        if volume > 0 {
            lastAudibleVolume = volume
            isAudioMuted = false
        }
        applyAudio()
    }

    private func applyAudio() {
        // Silence other sources before enabling the selected one, without
        // briefly muting a source that is already correctly selected.
        for (index, slot) in slots.enumerated() where index != audibleIndex {
            if !slot.isMuted { slot.isMuted = true }
        }
        for slot in slots where slot.volume != volume { slot.volume = volume }
        let selected = slots[audibleIndex]
        let muted = isAudioMuted || volume == 0
        if selected.isMuted != muted { selected.isMuted = muted }
    }
    func play(_ channel: Channel, client: OpenWebifClient, profile: ReceiverProfile, password: String, index: Int? = nil, selectSound: Bool = true, restoration: UUID? = nil) async {
        if selectSound { cancelRestore() }
        let selectedIndex = index ?? (isMultiview ? targetIndex : 0)
        guard slots.indices.contains(selectedIndex) else { return }
        let token = generation
        // A pending channel change follows this player if its tile is swapped.
        let selectedSlot = slots[selectedIndex]
        let request = UUID()
        pendingPlay[selectedSlot.id] = request
        do {
            let url = try await client.streamURL(for: channel)
            guard restoration == nil || restoration == restoreGeneration else {
                if pendingPlay[selectedSlot.id] == request { pendingPlay[selectedSlot.id] = nil }
                return
            }
            guard token == generation, pendingPlay[selectedSlot.id] == request, !Task.isCancelled,
                  let currentIndex = slots.firstIndex(where: { $0 === selectedSlot }),
                  currentIndex < (isMultiview ? visibleCount : 1) else { return }
            pendingPlay[selectedSlot.id] = nil
            selectedSlot.play(url: url, channel: channel, username: profile.username, password: password)
            if selectSound { selectAudio(currentIndex) }
            error = nil
        } catch {
            guard token == generation, pendingPlay[selectedSlot.id] == request, !Task.isCancelled,
                  restoration == nil || restoration == restoreGeneration else { return }
            pendingPlay[selectedSlot.id] = nil
            self.error = error.localizedDescription
        }
    }
    func setMultiview(_ active: Bool) {
        guard isMultiview != active else { return }
        cancelRestore()
        isMultiview = active; targetIndex = 0
        if !active { for slot in slots.dropFirst() { pendingPlay[slot.id] = nil; slot.stop() }; selectAudio(0) }
    }
    func setCount(_ count: Int) {
        cancelRestore()
        visibleCount = min(max(count, 2), 4)
        for index in visibleCount..<slots.count { pendingPlay[slots[index].id] = nil; slots[index].stop() }
        if audibleIndex >= visibleCount { selectAudio(0) }
        if targetIndex >= visibleCount { targetIndex = 0 }
    }
    func stopAll() { generation = UUID(); pendingPlay.removeAll(); for slot in slots { slot.stop() }; error = nil; targetIndex = 0; selectAudio(0) }

    private func cancelRestore() { restoreGeneration = UUID() }

    func stop(_ slot: PlaybackSlot) {
        cancelRestore(); pendingPlay[slot.id] = nil; slot.stop()
    }

    func preset(name: String, receiverID: UUID) -> MultiviewPreset {
        MultiviewPreset(name: name.trimmingCharacters(in: .whitespacesAndNewlines), receiverID: receiverID,
                        channels: Array(slots.prefix(visibleCount)).map(\.channel), audibleIndex: audibleIndex,
                        volume: volume, isMuted: isAudioMuted)
    }

    func restore(_ preset: MultiviewPreset, client: OpenWebifClient, profile: ReceiverProfile, password: String) async {
        guard preset.isValid, preset.receiverID == profile.id, !Task.isCancelled else { return }
        stopAll(); setMultiview(true); setCount(preset.channels.count)
        volume = preset.volume
        if volume > 0 { lastAudibleVolume = volume }
        isAudioMuted = preset.isMuted
        audibleIndex = preset.audibleIndex
        applyAudio()
        let token = generation
        let restoreToken = restoreGeneration
        // Match manual setup: establish the audible stream before starting
        // the other decoders, rather than opening every stream in one burst.
        let indices = [preset.audibleIndex] + preset.channels.indices.filter { $0 != preset.audibleIndex }
        let populated = indices.filter { preset.channels[$0] != nil }
        for (position, index) in populated.enumerated() {
            guard token == generation, restoreToken == restoreGeneration, !Task.isCancelled,
                  let channel = preset.channels[index] else { return }
            await play(channel, client: client, profile: profile, password: password,
                       index: index, selectSound: false, restoration: restoreToken)
            guard position < populated.count - 1 else { continue }
            let deadline = ContinuousClock.now + restoreStartupTimeout
            let slot = slots[index]
            while !slot.hasPresentedVideo, slot.status == .connecting || slot.status == .playing,
                  ContinuousClock.now < deadline {
                guard token == generation, restoreToken == restoreGeneration, !Task.isCancelled else { return }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }
}
