import Foundation

public struct FavoriteChannel: Codable, Identifiable, Sendable, Equatable {
    public let receiverID: UUID
    public var channel: Channel
    public var id: String { receiverID.uuidString + "|" + channel.id }
    public init(receiverID: UUID, channel: Channel) { self.receiverID = receiverID; self.channel = channel }
}
