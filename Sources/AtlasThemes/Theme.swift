import Foundation
import SwiftUI
import Observation

public struct ThemePalette: Codable, Sendable, Equatable {
    public var background: String
    public var backgroundEnd: String? = nil
    public var surface: String
    public var accent: String
    public var text: String
    public var secondary: String
    public var selection: String
    var colors: [String] { [background, surface, accent, text, secondary, selection] + [backgroundEnd].compactMap { $0 } }
}

public struct AtlasTheme: Codable, Identifiable, Sendable, Equatable {
    public var version: Int
    public var id: String
    public var name: String
    public var light: ThemePalette
    public var dark: ThemePalette
    public func palette(for scheme: ColorScheme) -> ThemePalette { scheme == .dark ? dark : light }
    public static let system = AtlasTheme(version: 1, id: "system", name: "System", light: .init(background: "#FAFAFC", surface: "#F0F0F4", accent: "#0068D8", text: "#202025", secondary: "#64646F", selection: "#D9EAFF"), dark: .init(background: "#242428", surface: "#2C2C32", accent: "#70B2FF", text: "#F0F0F5", secondary: "#B3B3BF", selection: "#244B72"))

    public static func decode(_ data: Data) throws -> AtlasTheme {
        let value = try JSONDecoder().decode(AtlasTheme.self, from: data)
        guard value.version == 1, !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.name.count <= 60,
              value.id.range(of: "^[a-z][a-z0-9-]{1,47}$", options: .regularExpression) != nil,
              (value.light.colors + value.dark.colors).allSatisfy({ $0.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return value
    }
}

public extension Color {
    init(atlasHex: String) {
        let value = UInt32(atlasHex.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

public extension EnvironmentValues {
    @Entry var atlasTheme: AtlasTheme = .system
}

private final class ThemeResourceMarker: NSObject {}

@MainActor @Observable
public final class ThemeCatalog {
    public private(set) var themes: [AtlasTheme] = [.system]
    public private(set) var invalidFileCount = 0
    public init() {}
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: ThemeResourceMarker.self)
        #endif
    }

    public func reload(customDirectory: URL?) {
        let bundle = Self.resourceBundle
        let builtin = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Themes")
            ?? ["ocean", "ivory", "bronze"].compactMap { bundle.url(forResource: $0, withExtension: "json") }
        let custom = customDirectory.flatMap {
            try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } ?? []
        // Bundled IDs are reserved. Custom duplicates are resolved by filename.
        let sources = [builtin, custom.filter { $0.pathExtension.lowercased() == "json" }]
        var found = [AtlasTheme.system]
        var failed = 0
        for files in sources {
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let bytes = try? Self.readTheme(file), let theme = try? AtlasTheme.decode(bytes),
                      !found.contains(where: { $0.id == theme.id }) else { failed += 1; continue }
                found.append(theme)
            }
        }
        if themes != found { themes = found }
        if invalidFileCount != failed { invalidFileCount = failed }
    }

    private static func readTheme(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 65_537) ?? Data()
        guard bytes.count <= 65_536 else { throw CocoaError(.fileReadCorruptFile) }
        return bytes
    }

    /// Creates a new editable theme without overwriting existing user files.
    public func createTemplate(in directory: URL, language: String = "de") throws -> (url: URL, theme: AtlasTheme) {
        let bundle = Self.resourceBundle
        let guideName = language == "en" ? "Theme-README.en" : "Theme-README"
        guard let template = bundle.url(forResource: "theme-template", withExtension: "json", subdirectory: "ThemeTemplates")
                ?? bundle.url(forResource: "theme-template", withExtension: "json"),
              let guide = bundle.url(forResource: guideName, withExtension: "md", subdirectory: "ThemeTemplates")
                ?? bundle.url(forResource: guideName, withExtension: "md") else { throw CocoaError(.fileNoSuchFile) }
        var theme = try AtlasTheme.decode(Self.readTheme(template))
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var index = 1
        var destination = directory.appendingPathComponent("mein-theme.json")
        let existingIDs = Set(themes.map(\.id))
        while manager.fileExists(atPath: destination.path) || existingIDs.contains(index == 1 ? "mein-theme" : "mein-theme-\(index)") {
            index += 1
            destination = directory.appendingPathComponent("mein-theme-\(index).json")
        }
        theme.id = index == 1 ? "mein-theme" : "mein-theme-\(index)"
        if language == "en" { theme.name = index == 1 ? "My theme" : "My theme \(index)" }
        else { theme.name = index == 1 ? "Mein Theme" : "Mein Theme \(index)" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(theme).write(to: destination, options: .withoutOverwriting)
        let instructions = directory.appendingPathComponent(guideName + ".md")
        if !manager.fileExists(atPath: instructions.path) { try manager.copyItem(at: guide, to: instructions) }
        return (destination, theme)
    }

    public func theme(id: String) -> AtlasTheme { themes.first { $0.id == id } ?? .system }
}

public struct AtlasThemeBackground: View {
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        let palette = theme.palette(for: scheme)
        if let end = palette.backgroundEnd {
            LinearGradient(colors: [Color(atlasHex: palette.background), Color(atlasHex: end)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(atlasHex: palette.background)
        }
    }
}
