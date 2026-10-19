import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import AtlasCore

public enum ReceiverAutoTimerTarget: Sendable, Equatable {
    case service(String)
    case bouquet(String)
}

/// The deliberately small rule subset that e2Atlas can safely round-trip.
public struct ReceiverAutoTimerRule: Sendable, Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let match: String
    public let enabled: Bool
    public let target: ReceiverAutoTimerTarget?
    public let beginTime: String?
    public let endTime: String?
    /// Monday through Sunday, represented as 1...7.
    public let weekdays: Set<Int>
    public let marginBefore: Int
    public let marginAfter: Int
    public let allowDuplicate: Bool
    public let isEditable: Bool
    public let unsupportedFields: [String]
    /// Receiver-specific duplicate comparison options, retained for stale-edit detection.
    public let descriptionComparisonFlags: [String: String]

    public init(id: Int, title: String, match: String, enabled: Bool, target: ReceiverAutoTimerTarget?,
                beginTime: String?, endTime: String?, weekdays: Set<Int>, marginBefore: Int, marginAfter: Int,
                allowDuplicate: Bool, isEditable: Bool, unsupportedFields: [String], descriptionComparisonFlags: [String: String] = [:]) {
        self.id = id; self.title = title; self.match = match; self.enabled = enabled; self.target = target
        self.beginTime = beginTime; self.endTime = endTime; self.weekdays = weekdays
        self.marginBefore = marginBefore; self.marginAfter = marginAfter; self.allowDuplicate = allowDuplicate
        self.isEditable = isEditable; self.unsupportedFields = unsupportedFields
        self.descriptionComparisonFlags = descriptionComparisonFlags
    }
}

public struct ReceiverAutoTimerDraft: Sendable, Equatable {
    public var title: String
    public var match: String
    public var enabled: Bool
    public var target: ReceiverAutoTimerTarget
    public var beginTime: String?
    public var endTime: String?
    public var weekdays: Set<Int>
    public var marginBefore: Int
    public var marginAfter: Int
    public var allowDuplicate: Bool

    public init(title: String, match: String, enabled: Bool = true, target: ReceiverAutoTimerTarget,
                beginTime: String? = nil, endTime: String? = nil, weekdays: Set<Int> = [],
                marginBefore: Int = 0, marginAfter: Int = 0, allowDuplicate: Bool = false) {
        self.title = title; self.match = match; self.enabled = enabled; self.target = target
        self.beginTime = beginTime; self.endTime = endTime; self.weekdays = weekdays
        self.marginBefore = marginBefore; self.marginAfter = marginAfter; self.allowDuplicate = allowDuplicate
    }
}

public enum ReceiverAutoTimerError: Error, LocalizedError, Sendable {
    case unsupportedRule, unsupportedDefaults, invalidDraft, rejected, changed
    public var errorDescription: String? {
        switch self {
        case .unsupportedRule: "Diese AutoTimer-Regel enthält nicht unterstützte Einstellungen und ist schreibgeschützt."
        case .unsupportedDefaults: "Der Receiver verwendet zusätzliche AutoTimer-Standardwerte. Neue Regeln können diese Werte hier nicht sicher übernehmen."
        case .invalidDraft: "Die AutoTimer-Regel ist unvollständig oder ungültig."
        case .rejected: "Der Receiver hat die AutoTimer-Änderung abgelehnt."
        case .changed: "Die AutoTimer-Regel wurde seit dem Laden geändert. Bitte neu laden."
        }
    }
}

final class ReceiverAutoTimerXML: NSObject, XMLParserDelegate {
    private(set) var rules: [ReceiverAutoTimerRule] = []
    private(set) var success: Bool?
    private var root: String?
    private var current: [String: String]?
    private var currentID = -1
    private var tag: String?
    private var text = ""
    private var childData: [String: String] = [:]
    private var unsupported: [String] = []
    private var targetCount = 0
    private var insideDefaults = false
    private(set) var hasNontrivialDefaults = false

    static func parse(_ data: Data, expectedRoot: String) throws -> Self {
        guard data.count <= 2_000_000 else { throw AtlasFailure.invalidResponse }
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let result = Self()
        parser.delegate = result
        guard parser.parse(), result.root == expectedRoot else { throw AtlasFailure.invalidResponse }
        return result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        if root == nil { root = elementName }
        text = ""
        if elementName == "defaults" {
            insideDefaults = true
            // UTF-8 is the supported text encoding, not an additional rule restriction.
            if attributes.contains(where: { entry in
                entry.key != "id" && !(entry.key == "encoding" && entry.value.caseInsensitiveCompare("UTF-8") == .orderedSame)
            }) { hasNontrivialDefaults = true }
        } else if insideDefaults {
            hasNontrivialDefaults = true
        }
        if elementName == "timer" {
            current = attributes; childData = [:]; unsupported = []; targetCount = 0
            currentID = Int(attributes["id"] ?? "") ?? -1
        } else if current != nil {
            tag = elementName
            if elementName == "include" || elementName == "exclude" { tag = elementName + ":" + (attributes["where"] ?? "") }
            let supported: Set<String> = ["e2service", "e2servicereference", "e2servicename", "include", "exclude"]
            if !supported.contains(elementName) { unsupported.append(elementName) }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "defaults" { insideDefaults = false }
        if elementName == "e2state" { success = value.lowercased() == "true" ? true : value.lowercased() == "false" ? false : nil }
        if current != nil {
            if elementName == "e2servicereference" { childData["target"] = value; targetCount += 1 }
            if elementName == "include" || elementName == "exclude" {
                let key = tag ?? ""
                if key == "include:dayofweek" { childData["weekday", default: ""] += (childData["weekday"]?.isEmpty == false ? "," : "") + value }
                else if key.hasPrefix("include:") { unsupported.append("include filter") }
                else if key.hasPrefix("exclude:") { unsupported.append("exclude filter") }
                tag = nil
            }
            if let tag, elementName == tag { childData[tag] = value; self.tag = nil }
        }
        if elementName == "timer", let attrs = current {
            var flags = unsupported
            if targetCount != 1 { flags.append(targetCount == 0 ? "missing target" : "multiple targets") }
            rules.append(Self.makeRule(id: currentID, attrs: attrs, children: childData, unsupported: flags))
            current = nil
        }
        text = ""
    }

    private static func makeRule(id: Int, attrs: [String: String], children: [String: String], unsupported: [String]) -> ReceiverAutoTimerRule {
        let knownAttributes: Set<String> = ["id", "name", "match", "enabled", "searchType", "encoding", "searchCase", "justplay", "setEndtime", "avoidDuplicateDescription", "searchForDuplicateDescription", "counter", "left", "counterFormat", "lastBegin", "lastActivation", "offset", "tag", "location", "overrideAlternatives", "vps_enabled", "vps_overwrite", "series_labeling", "always_zap", "from", "to", "after", "before", "maxduration", "descShortEqualExt", "descShortExtEmpty"]
        var unknown = unsupported
        unknown += attrs.keys.filter { !knownAttributes.contains($0) }
        let enabled = attrs["enabled"].map { ["1", "true", "yes"].contains($0.lowercased()) } ?? false
        if let value = attrs["enabled"], !["0", "1", "true", "false", "yes", "no"].contains(value.lowercased()) { unknown.append("enabled") }
        if let encoding = attrs["encoding"], encoding.lowercased() != "utf-8" { unknown.append("encoding") }
        for name in ["counter", "left", "counterFormat", "lastBegin", "lastActivation", "tag", "location", "overrideAlternatives", "vps_enabled", "vps_overwrite", "series_labeling", "always_zap"] where attrs[name] != nil {
            unknown.append(name)
        }
        // OpenPLi keeps these values unchanged when an edit omits their form fields.
        let comparisonFlags = attrs.filter { ["descShortEqualExt", "descShortExtEmpty"].contains($0.key) }
        for (key, value) in comparisonFlags where !["yes", "no", "0", "1"].contains(value) { unknown.append(key) }
        let weekdayNames = ["Monday": 1, "Tuesday": 2, "Wednesday": 3, "Thursday": 4, "Friday": 5, "Saturday": 6, "Sunday": 7]
        let weekdayRaw = (children["weekday"] ?? "").split(separator: ",")
        let weekdayTokens = weekdayRaw.compactMap { token -> Int? in
            if let number = Int(token), (0...6).contains(number) { return number + 1 }
            return weekdayNames[String(token)]
        }
        if weekdayTokens.count != weekdayRaw.count { unknown.append("weekday filter") }
        let weekdays = Set(weekdayTokens.filter { (1...7).contains($0) })
        let target: ReceiverAutoTimerTarget?
        if let reference = children["target"], !reference.isEmpty {
            target = reference.hasPrefix("1:7:") ? .bouquet(reference) : .service(reference)
        } else { target = nil }
        let offset = (attrs["offset"] ?? "0").split(separator: ",").compactMap { Int($0) }
        if offset.isEmpty || offset.count > 2 || (attrs["offset"] != nil && offset.count != attrs["offset"]!.split(separator: ",").count) {
            unknown.append("offset")
        }
        let before = offset.first ?? 0
        let after = offset.count > 1 ? offset[1] : before
        if before > 1440 || after > 1440 { unknown.append("offset") }
        let begin = attrs["from"]
        let end = attrs["to"]
        let validTime = [begin, end].compactMap { $0 }.allSatisfy { t in
            let p = t.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 && (0...23).contains(p[0]) && (0...59).contains(p[1])
        }
        if (begin == nil) != (end == nil) || !validTime { unknown.append("timespan") }
        if let searchType = attrs["searchType"], searchType != "partial" { unknown.append("searchType") }
        if attrs["searchCase"] != nil { unknown.append("searchCase") }
        if attrs["justplay"] != nil { unknown.append("justplay") }
        let duplicateMode = Int(attrs["avoidDuplicateDescription"] ?? "0") ?? -1
        if !(0...1).contains(duplicateMode) || attrs["searchForDuplicateDescription"].map({ $0 != "2" }) == true { unknown.append("duplicate mode") }
        if attrs["after"] != nil || attrs["before"] != nil || attrs["maxduration"] != nil { unknown.append("time limits") }
        let simple = id >= 0 && attrs["name"] != nil && attrs["match"] != nil
            && (attrs["searchType"] == nil || attrs["searchType"] == "partial")
            && attrs["searchCase"] == nil && attrs["justplay"] == nil
            && unknown.allSatisfy({ $0 != "duplicate mode" })
            && attrs["after"] == nil && attrs["before"] == nil && attrs["maxduration"] == nil
            && before >= 0 && after >= 0 && target != nil && unknown.isEmpty
        return ReceiverAutoTimerRule(id: id, title: attrs["name"] ?? "", match: attrs["match"] ?? "", enabled: enabled,
            target: target, beginTime: begin, endTime: end, weekdays: weekdays, marginBefore: before,
            marginAfter: after, allowDuplicate: duplicateMode == 0, isEditable: simple,
            unsupportedFields: Array(Set(unknown)).sorted(), descriptionComparisonFlags: comparisonFlags)
    }
}
