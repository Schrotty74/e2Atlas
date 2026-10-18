import Foundation
import CoreFoundation

public struct ReceiverTimer: Identifiable, Sendable, Equatable {
    public let serviceReference: String
    public let serviceName: String
    public let eventID: Int64
    public let name: String
    public let description: String
    public let beginEpoch: Int64
    public let endEpoch: Int64
    public let disabled: Bool
    public let justPlay: Bool
    public let afterEvent: Int
    public let directory: String
    public let tags: String
    public let repeated: Int
    public let state: Int
    public let cancelled: Bool
    public let autoTimer: Bool
    public let autoTimerStatus: Int64
    public let vpsEnabled: Bool
    public let vpsOverwrite: Bool
    public let vpsTime: Int64
    public let pipZap: Int
    public let alwaysZap: Int
    public let allowDuplicate: Bool
    public let autoAdjust: Int
    public let recordingType: String
    public let iceTimerID: Int64
    public let dontSave: Bool
    public let hasUnknownFields: Bool

    public var id: String { "\(serviceReference)|\(beginEpoch)|\(endEpoch)" }
    public var begin: Date { Date(timeIntervalSince1970: TimeInterval(beginEpoch)) }
    public var end: Date { Date(timeIntervalSince1970: TimeInterval(endEpoch)) }
    /// Allows ordinary one-off recordings with known metadata; allow-duplicate and auto-adjust values are preserved by the edit request.
    public var isEditable: Bool {
        !serviceReference.isEmpty && endEpoch > beginEpoch && !justPlay && repeated == 0
            && autoTimerStatus >= -1 && !autoTimer && !vpsEnabled && !vpsOverwrite && vpsTime == -1
            && pipZap == -1 && !cancelled && !dontSave && recordingType == "normal"
            && iceTimerID == -1 && state == 0 && end > Date() && !hasUnknownFields
    }

    static func decode(_ row: [String: Any]) -> ReceiverTimer? {
        guard let serviceReference = row["serviceref"] as? String,
              let begin = Self.integer(row["begin"]), let end = Self.integer(row["end"]),
              (-62_135_596_800...253_402_300_799).contains(begin),
              (-62_135_596_800...253_402_300_799).contains(end), end > begin else { return nil }
        let knownFields: Set<String> = [
            "serviceref", "servicename", "eit", "name", "description", "descriptionextended",
            "disabled", "begin", "end", "duration", "startprepare", "justplay", "afterevent",
            "dirname", "tags", "logentries", "backoff", "firsttryprepare", "state", "repeated",
            "dontsave", "cancelled", "toggledisabled", "toggledisabledimg", "filename", "nextactivation",
            "realbegin", "realend", "asrefs", "vpsplugin_enabled", "vpsplugin_overwrite", "vpsplugin_time",
            "always_zap", "pipzap", "isAutoTimer", "allow_duplicate", "autoadjust", "recordingtype", "ice_timer_id"
        ]
        let allowDuplicateValue = Self.integer(row["allow_duplicate"])
        let autoAdjustValue = Self.integer(row["autoadjust"])
        let afterEventValue = Self.integer(row["afterevent"])
        let repeatedValue = Self.integer(row["repeated"])
        let stateValue = Self.integer(row["state"])
        let pipZapValue = Self.integer(row["pipzap"])
        let alwaysZapValue = Self.integer(row["always_zap"])
        let autoTimerRawValue = Self.integer(row["isAutoTimer"])
        let autoTimerFlag = Self.flag(row["isAutoTimer"])
        let autoTimerStatus = autoTimerRawValue == -1 ? -1 : autoTimerFlag.map { $0 ? Int64(1) : Int64(0) } ?? -2
        let timerTags = row["tags"] as? String ?? ""
        let isAutoTimerTagged = timerTags.split(whereSeparator: \.isWhitespace).contains("AutoTimer")
        let disabledFlag = Self.flag(row["disabled"])
        let justPlayFlag = Self.flag(row["justplay"])
        let cancelledFlag = Self.flag(row["cancelled"])
        let dontSaveFlag = Self.flag(row["dontsave"])
        let vpsEnabledFlag = Self.flag(row["vpsplugin_enabled"])
        let vpsOverwriteFlag = Self.flag(row["vpsplugin_overwrite"])
        let recordingTypeValue = row["recordingtype"] as? String
        let hasUnsupportedValues = (allowDuplicateValue.map { ![0, 1].contains($0) } ?? (row["allow_duplicate"] != nil))
            || (autoAdjustValue.map { ![-1, 0, 1].contains($0) } ?? (row["autoadjust"] != nil))
            || (afterEventValue.map { !(Int64(0)...Int64(3)).contains($0) } ?? (row["afterevent"] != nil))
            || (repeatedValue.map { $0 < 0 } ?? (row["repeated"] != nil))
            || (pipZapValue.map { ![-1, 0, 1].contains($0) } ?? (row["pipzap"] != nil))
            || (alwaysZapValue.map { ![-1, 0, 1].contains($0) } ?? (row["always_zap"] != nil))
            || (row["recordingtype"] != nil && recordingTypeValue == nil)
            || disabledFlag == nil || justPlayFlag == nil || cancelledFlag == nil || dontSaveFlag == nil
            || vpsEnabledFlag == nil || vpsOverwriteFlag == nil
            || row["isAutoTimer"] == nil || autoTimerStatus < -1 || autoTimerStatus > 1
            || row["vpsplugin_time"] == nil || Self.integer(row["vpsplugin_time"]) == nil
            || row["pipzap"] == nil || pipZapValue == nil || row["always_zap"] == nil || alwaysZapValue == nil
            || row["afterevent"] == nil || afterEventValue == nil
            || row["allow_duplicate"] == nil || allowDuplicateValue == nil
            || row["autoadjust"] == nil || autoAdjustValue == nil
            || row["state"] == nil || stateValue == nil || !(Int64(0)...Int64(3)).contains(stateValue ?? -1)
            || row["recordingtype"] == nil || row["ice_timer_id"] == nil || Self.integer(row["ice_timer_id"]) == nil
            || row["repeated"] == nil || repeatedValue == nil
            || !(row["name"] is String) || !(row["description"] is String)
            || !(row["dirname"] is String) || !(row["tags"] is String)
        return ReceiverTimer(
            serviceReference: serviceReference,
            serviceName: row["servicename"] as? String ?? "",
            eventID: Self.integer(row["eit"]) ?? 0,
            name: row["name"] as? String ?? "",
            description: row["description"] as? String ?? "",
            beginEpoch: begin, endEpoch: end,
            disabled: disabledFlag ?? false,
            justPlay: justPlayFlag ?? false,
            afterEvent: Int(afterEventValue ?? 3),
            directory: (row["dirname"] as? String).flatMap { $0 == "None" ? nil : $0 } ?? "",
            tags: timerTags,
            repeated: Int(repeatedValue ?? 0),
            state: Int(stateValue ?? -1),
            cancelled: cancelledFlag ?? false,
            autoTimer: autoTimerStatus == 1 || isAutoTimerTagged,
            autoTimerStatus: autoTimerStatus,
            vpsEnabled: vpsEnabledFlag ?? false,
            vpsOverwrite: vpsOverwriteFlag ?? false,
            vpsTime: Self.integer(row["vpsplugin_time"]) ?? -1,
            pipZap: Int(pipZapValue ?? -1),
            alwaysZap: Int(alwaysZapValue ?? -1),
            allowDuplicate: allowDuplicateValue.map { $0 != 0 } ?? true,
            autoAdjust: Int(autoAdjustValue ?? -1),
            recordingType: recordingTypeValue ?? "normal",
            iceTimerID: Self.integer(row["ice_timer_id"]) ?? -1,
            dontSave: dontSaveFlag ?? false,
            hasUnknownFields: !Set(row.keys).isSubset(of: knownFields) || hasUnsupportedValues
        )
    }

    private static func integer(_ value: Any?) -> Int64? {
        if let n = value as? NSNumber {
            guard CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
            let double = n.doubleValue
            guard double.isFinite, double.rounded(.towardZero) == double,
                  double >= -9_223_372_036_854_775_808.0,
                  double < 9_223_372_036_854_775_808.0 else { return nil }
            return n.int64Value
        }
        if let s = value as? String { return Int64(s) }
        return nil
    }

    private static func flag(_ value: Any?) -> Bool? {
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
            guard let integer = integer(n), integer == 0 || integer == 1 else { return nil }
            return integer == 1
        }
        if let string = value as? String {
            switch string.lowercased() {
            case "0", "false": return false
            case "1", "true": return true
            default: return nil
            }
        }
        return nil
    }
}

public struct ReceiverTimerDraft: Sendable, Equatable {
    public var serviceReference: String
    public var begin: Date
    public var end: Date
    public var name: String
    public var description: String
    public var disabled: Bool
    public var justPlay: Bool
    public var afterEvent: Int
    public var directory: String
    public var tags: String
    public var eventID: Int64
    public var alwaysZap: Int
    public var allowDuplicate: Bool
    public var autoAdjust: Int

    public init(serviceReference: String, begin: Date, end: Date, name: String,
                description: String = "", disabled: Bool = false, justPlay: Bool = false,
                afterEvent: Int = 3, directory: String = "", tags: String = "",
                eventID: Int64 = 0, alwaysZap: Int = -1,
                allowDuplicate: Bool = true, autoAdjust: Int = -1) {
        self.serviceReference = serviceReference; self.begin = begin; self.end = end
        self.name = name; self.description = description; self.disabled = disabled
        self.justPlay = justPlay; self.afterEvent = afterEvent; self.directory = directory
        self.tags = tags; self.eventID = eventID; self.alwaysZap = alwaysZap
        self.allowDuplicate = allowDuplicate; self.autoAdjust = autoAdjust
    }

    public init(editing timer: ReceiverTimer) {
        self.init(serviceReference: timer.serviceReference, begin: timer.begin, end: timer.end,
                  name: timer.name, description: timer.description, disabled: timer.disabled,
                  justPlay: timer.justPlay, afterEvent: timer.afterEvent, directory: timer.directory,
                  tags: timer.tags, eventID: timer.eventID, alwaysZap: timer.alwaysZap,
                  allowDuplicate: timer.allowDuplicate, autoAdjust: timer.autoAdjust)
    }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "sRef", value: serviceReference),
            URLQueryItem(name: "begin", value: Self.epoch(begin)),
            URLQueryItem(name: "end", value: Self.epoch(end)),
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "description", value: description),
            URLQueryItem(name: "disabled", value: disabled ? "1" : "0"),
            URLQueryItem(name: "justplay", value: justPlay ? "1" : "0"),
            URLQueryItem(name: "afterevent", value: String(afterEvent)),
            URLQueryItem(name: "dirname", value: directory),
            URLQueryItem(name: "tags", value: tags),
            URLQueryItem(name: "repeated", value: "0"),
            URLQueryItem(name: "eit", value: String(eventID)),
            URLQueryItem(name: "always_zap", value: String(alwaysZap)),
            URLQueryItem(name: "allow_duplicate", value: allowDuplicate ? "1" : "0"),
            URLQueryItem(name: "autoadjust", value: String(autoAdjust))
        ].filter { $0.name != "dirname" || !directory.isEmpty }
    }

    private static func epoch(_ date: Date) -> String {
        let value = date.timeIntervalSince1970
        guard value.isFinite, value >= Double(Int64.min), value <= Double(Int64.max) else { return "0" }
        return String(Int64(value))
    }
}

public enum ReceiverTimerMutationError: Error, LocalizedError, Sendable, Equatable {
    case conflict
    case rejected

    public var errorDescription: String? {
        switch self {
        case .conflict: "Der Receiver meldet einen möglichen Timerkonflikt. Prüfe die Timerliste am Receiver."
        case .rejected: "Der Receiver hat die Timeränderung abgelehnt."
        }
    }
}
