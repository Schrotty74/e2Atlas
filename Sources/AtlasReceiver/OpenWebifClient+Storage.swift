import Foundation
import AtlasCore

public extension OpenWebifClient {
    /// Reads OpenWebif's read-only `/api/boxinfo` HDD list. Returned free-space
    /// and capacity fields are display strings supplied by the receiver.
    func storageInfo() async throws -> [ReceiverStorage] {
        do { return try ReceiverStorage.decodeList(from: await object(path: "/api/boxinfo")) }
        catch AtlasFailure.invalidResponse { return try ReceiverStorage.decodeList(from: await object(path: "/api/about")) }
    }
}
