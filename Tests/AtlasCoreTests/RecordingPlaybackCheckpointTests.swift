import Foundation
import Testing
@testable import AtlasCore

@Suite("Recording playback checkpoints")
struct RecordingPlaybackCheckpointTests {
    @Test func resumeWindowAndIdentityAreReceiverScoped() throws {
        let receiver = UUID()
        let value = try #require(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: 30, duration: 120))
        #expect(value.isValid)
        #expect(value.isResumable)

        let otherReceiver = try #require(RecordingPlaybackCheckpoint(receiverID: UUID(), recordingID: "movie", seconds: 30, duration: 120))
        #expect(value.id != otherReceiver.id)
        #expect(try JSONDecoder().decode(RecordingPlaybackCheckpoint.self, from: JSONEncoder().encode(value)) == value)
    }

    @Test func rejectsInvalidNumbersAndEmptyIdentity() {
        let receiver = UUID()
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "", seconds: 10, duration: 100) == nil)
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: -.infinity, duration: 100) == nil)
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: .nan, duration: 100) == nil)
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: 10, duration: .infinity) == nil)
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: -1, duration: 100) == nil)
        #expect(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "movie", seconds: 100, duration: 100) == nil)
    }

    @Test func filtersEarlyAndNearEndPositions() throws {
        let receiver = UUID()
        let beginning = try #require(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "early", seconds: 2, duration: 100))
        let nearEnd = try #require(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "late", seconds: 85, duration: 100))
        let resumable = try #require(RecordingPlaybackCheckpoint(receiverID: receiver, recordingID: "middle", seconds: 84, duration: 100))
        #expect(!beginning.isResumable)
        #expect(!nearEnd.isResumable)
        #expect(resumable.isResumable)
    }
}
