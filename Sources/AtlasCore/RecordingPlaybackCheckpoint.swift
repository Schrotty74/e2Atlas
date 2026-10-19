import Foundation

/// Locally saved resume position for one receiver recording.
public struct RecordingPlaybackCheckpoint: Codable, Sendable, Equatable, Identifiable {
    public static let resumeThreshold: TimeInterval = 2
    public static let completionMargin: TimeInterval = 15

    public let receiverID: UUID
    public let recordingID: String
    public let seconds: TimeInterval
    public let duration: TimeInterval
    public let updatedAt: Date

    public var id: String { "\(receiverID.uuidString)|\(recordingID)" }
    public var isValid: Bool {
        !recordingID.isEmpty && recordingID.utf8.count <= 8_192 && seconds.isFinite && seconds >= 0
            && duration.isFinite && duration > 0 && seconds < duration
            && updatedAt.timeIntervalSince1970.isFinite
    }
    public var isResumable: Bool {
        isValid && seconds > Self.resumeThreshold
            && duration - seconds > Self.completionMargin
    }

    public init?(receiverID: UUID, recordingID: String, seconds: TimeInterval,
                 duration: TimeInterval, updatedAt: Date = .now) {
        guard !recordingID.isEmpty, recordingID.utf8.count <= 8_192, seconds.isFinite, seconds >= 0,
              duration.isFinite, duration > 0, seconds < duration,
              updatedAt.timeIntervalSince1970.isFinite else { return nil }
        self.receiverID = receiverID
        self.recordingID = recordingID
        self.seconds = seconds
        self.duration = duration
        self.updatedAt = updatedAt
    }
}
