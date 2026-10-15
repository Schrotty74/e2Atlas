import Foundation
import SwiftUI
import Observation

public struct ThemePalette: Codable, Sendable, Equatable {
    public var background: String
    public var surface: String
    public var accent: String
    public var text: String
    public var secondary: String
    public var selection: String
    var colors: [String] { [background, surface, accent, text, secondary, selection] }
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
        guard value.version == 1, !value.name.isEmpty, value.name.count <= 60,
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

@MainActor @Observable
public final class ThemeCatalog {
    public private(set) var themes: [AtlasTheme] = [.system]
    public private(set) var invalidFileCount = 0
    public init() {}
    public func reload(customDirectory: URL?) {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        var files = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Themes") ?? bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        if let customDirectory, let custom = try? FileManager.default.contentsOfDirectory(at: customDirectory, includingPropertiesForKeys: nil) {
            files += custom.filter { $0.pathExtension.lowercased() == "json" }
        }
        var found = [AtlasTheme.system]; var failed = 0
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let bytes = try? Data(contentsOf: file), bytes.count <= 65_536,
                  let theme = try? AtlasTheme.decode(bytes), theme.id != "system",
                  !found.contains(where: { $0.id == theme.id }) else { failed += 1; continue }
            found.append(theme)
        }
        themes = found; invalidFileCount = failed
    }
    public func theme(id: String) -> AtlasTheme { themes.first { $0.id == id } ?? .system }
}
