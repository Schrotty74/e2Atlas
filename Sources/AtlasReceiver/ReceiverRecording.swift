import Foundation
import CoreFoundation

/// A recording listed by OpenWebif. `filePath` is a receiver-side path, never a local file URL.
public struct ReceiverRecording: Identifiable, Sendable, Equatable {
    public let serviceReference: String
    public let title: String
    public let description: String
    public let serviceName: String
    public let begin: Date?
    public let duration: TimeInterval?
    public let size: Int64?
    public let filePath: String

    public var id: String { "\(serviceReference)|\(filePath)" }

    public init(serviceReference: String, title: String, description: String,
                serviceName: String, begin: Date?, duration: TimeInterval?,
                size: Int64?, filePath: String) {
        self.serviceReference = serviceReference
        self.title = title
        self.description = description
        self.serviceName = serviceName
        self.begin = begin
        self.duration = duration
        self.size = size
        self.filePath = filePath
    }

    static func decode(_ row: [String: Any]) -> ReceiverRecording? {
        guard let serviceReference = row["serviceref"] as? String, !serviceReference.isEmpty,
              let title = row["eventname"] as? String,
              let filePath = row["filename"] as? String,
              Self.validReceiverPath(filePath) else { return nil }
        let begin = Self.number(row["recordingtime"]).flatMap { seconds -> Date? in
            guard seconds >= -62_135_596_800, seconds <= 253_402_300_799 else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
        return ReceiverRecording(
            serviceReference: serviceReference,
            title: title,
            description: row["description"] as? String ?? "",
            serviceName: row["servicename"] as? String ?? "",
            begin: begin,
            duration: Self.duration(row["length"]),
            size: Self.integer(row["filesize"]),
            filePath: filePath
        )
    }

    static func validReceiverPath(_ path: String) -> Bool {
        guard path.hasPrefix("/"), !path.hasPrefix("//"),
              !path.contains("\\"), !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains("..") && !components.contains(".")
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        return value.isFinite ? value : nil
    }

    private static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double >= 0, double.rounded(.towardZero) == double,
              double < 9_223_372_036_854_775_808.0 else { return nil }
        return number.int64Value
    }

    private static func duration(_ value: Any?) -> TimeInterval? {
        guard let string = value as? String else { return nil }
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0) }
        guard (2...3).contains(parts.count), values.count == parts.count,
              values.allSatisfy({ $0 >= 0 }), values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        let leading = values[0].multipliedReportingOverflow(by: values.count == 3 ? 3_600 : 60)
        let middle = values.count == 3 ? values[1].multipliedReportingOverflow(by: 60) : (partialValue: values[1], overflow: false)
        guard !leading.overflow, !middle.overflow else { return nil }
        let subtotal = leading.partialValue.addingReportingOverflow(middle.partialValue)
        guard !subtotal.overflow else { return nil }
        let total = subtotal.partialValue.addingReportingOverflow(values.count == 3 ? values[2] : 0)
        guard !total.overflow, total.partialValue > 0 else { return nil }
        return TimeInterval(total.partialValue)
    }
}

public struct ReceiverRecordingDirectory: Identifiable, Sendable, Equatable {
    public let path: String
    public let name: String
    public var id: String { path }

    public init(path: String, name: String) {
        self.path = path
        self.name = name
    }
}

public struct ReceiverRecordingPage: Sendable, Equatable {
    public let recordings: [ReceiverRecording]
    public let directories: [ReceiverRecordingDirectory]
    public let currentDirectory: String?

    public init(recordings: [ReceiverRecording], directories: [ReceiverRecordingDirectory], currentDirectory: String?) {
        self.recordings = recordings
        self.directories = directories
        self.currentDirectory = currentDirectory
    }
}
