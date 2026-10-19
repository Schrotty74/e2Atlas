import Foundation
import AtlasCore

/// A mounted recording-capable disk as reported by OpenWebif's box information.
/// Capacity and free-space values are preserved exactly as returned by the receiver,
/// because OpenWebif supplies localized display strings rather than numeric byte counts.
public struct ReceiverStorage: Identifiable, Sendable, Equatable {
    public let id: Int
    public let model: String?
    public let capacity: String?
    public let free: String?
    public let mountPath: String?

    static func decodeList(from json: [String: Any]) throws -> [ReceiverStorage] {
        let info = json["info"] as? [String: Any] ?? json
        guard let rows = info["hdd"] as? [[String: Any]] else { throw AtlasFailure.invalidResponse }
        return rows.enumerated().map { index, row in
            let mount = normalizedMount(text(row["mount"]))
            return ReceiverStorage(id: index,
                                   model: text(row["model"]),
                                   capacity: text(row["capacity"]) ?? text(row["labelled_capacity"]),
                                   free: mount == nil ? nil : text(row["free"]),
                                   mountPath: mount)
        }
    }

    /// Returns true only when the receiver's reported mount is a path ancestor
    /// of the selected recording directory.
    public func containsRecordingDirectory(_ directory: String?) -> Bool {
        guard let mountPath, let directory = Self.normalizedMount(directory) else { return false }
        return directory == mountPath || directory.hasPrefix(mountPath == "/" ? "/" : mountPath + "/")
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedMount(_ value: String?) -> String? {
        guard let value, value.hasPrefix("/"), !value.contains("\\") else { return nil }
        let components = value.split(separator: "/")
        guard !components.contains(".") && !components.contains("..") else { return nil }
        let result = "/" + components.joined(separator: "/")
        return result.isEmpty ? "/" : result
    }
}
