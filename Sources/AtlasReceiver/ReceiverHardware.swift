import Foundation
import AtlasCore

public struct ReceiverTuner: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let type: String?
    public let live: Bool
    public let recording: Bool
    public let streaming: Bool
    public let statusAvailable: Bool
    public var isActive: Bool { live || recording || streaming }
}

public struct ReceiverHardware: Sendable, Equatable {
    public let brand: String?
    public let model: String?
    public let chipset: String?
    public let image: String?
    public let imageVersion: String?
    public let enigmaVersion: String?
    public let kernelVersion: String?
    public let webifVersion: String?
    public let memory: String?
    public let uptime: String?
    public let tuners: [ReceiverTuner]
    public let tunerListAvailable: Bool
    public let streamCount: Int?
    public let unassignedStreamCount: Int
    public var activeTunerCount: Int { tuners.filter(\.isActive).count }
    public var allTunerStatusesAvailable: Bool { tunerListAvailable && unassignedStreamCount == 0 && tuners.allSatisfy(\.statusAvailable) }

    // Only explicitly supported hardware fields are retained. Network interfaces,
    // serial numbers, stream clients and raw receiver diagnostics are discarded.
    static func decode(_ json: [String: Any]) throws -> ReceiverHardware {
        let info = json["info"] as? [String: Any] ?? json
        func text(_ key: String) -> String? { string(info[key]) }
        let rows = info["tuners"] as? [[String: Any]]
        let model = text("model") ?? text("machinebuild") ?? text("boxtype")
        let image = text("friendlyimagedistro") ?? text("imagedistro") ?? text("oever")
        guard model != nil || image != nil || rows != nil else { throw AtlasFailure.invalidResponse }
        let usageFailed = text("EX") != nil
        let streams = info["streams"] as? [[String: Any]]
        var streamTuners = Set<Int>()
        var unassignedStreamCount = 0
        for stream in streams ?? [] {
            if let index = tunerIndex(stream["tuner_number"]), let rows, rows.indices.contains(index) {
                streamTuners.insert(index)
            } else {
                // Stream count is not tuner count: a transponder may be shared.
                unassignedStreamCount += 1
            }
        }
        let tuners = (rows ?? []).enumerated().map { index, row in
            let live = string(row["live"]) != nil
            let recording = string(row["rec"]) != nil
            let streaming = string(row["stream"]) != nil || streamTuners.contains(index)
            let available = !usageFailed && unassignedStreamCount == 0 && ["live", "rec", "stream"].allSatisfy { row[$0] is String }
            return ReceiverTuner(id: index, name: string(row["name"]) ?? "Tuner \(index + 1)",
                                 type: string(row["type"]), live: live, recording: recording,
                                 streaming: streaming, statusAvailable: available)
        }
        return ReceiverHardware(brand: text("brand"), model: model, chipset: text("chipset"),
                                image: image, imageVersion: text("imagever"), enigmaVersion: text("enigmaver"),
                                kernelVersion: text("kernelver"), webifVersion: text("webifver") ?? text("owiver"),
                                memory: text("mem3"), uptime: text("uptime"), tuners: tuners,
                                tunerListAvailable: rows != nil, streamCount: streams?.count,
                                unassignedStreamCount: unassignedStreamCount)
    }

    private static func tunerIndex(_ value: Any?) -> Int? {
        if let value = value as? String { return Int(value) }
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        let number = value.doubleValue
        guard number.isFinite, number >= 0, number < Double(Int.max), number.rounded() == number else { return nil }
        return Int(number)
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
