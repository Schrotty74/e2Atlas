import Foundation
import SwiftUI
import Testing
@testable import AtlasThemes

@Suite("Atlas theme validation")
struct AtlasThemeTests {
    @Test func decodesValidThemeAndSelectsPaletteByColorScheme() throws {
        let theme = try AtlasTheme.decode(try JSONEncoder().encode(validTheme()))
        #expect(theme.id == "ocean-test")
        #expect(theme.palette(for: .light) == theme.light)
        #expect(theme.palette(for: .dark) == theme.dark)
    }

    @Test(arguments: ["unsupported-version", "short-id", "invalid-id", "empty-name", "long-name", "invalid-color"])
    func rejectsInvalidThemeFields(field: String) throws {
        let data = try encodedTheme(mutating: field)
        var rejected = false
        do {
            _ = try AtlasTheme.decode(data)
        } catch {
            rejected = true
        }
        #expect(rejected)
    }

    @Test @MainActor func catalogSkipsInvalidCustomFilesAndFallsBackToSystemTheme() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2Atlas-ThemeTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(validTheme()).write(to: directory.appendingPathComponent("custom.json"))
        try encodedTheme(mutating: "invalid-color").write(to: directory.appendingPathComponent("invalid.json"))

        let catalog = ThemeCatalog()
        catalog.reload(customDirectory: directory)

        #expect(catalog.theme(id: "ocean-test").name == "Test theme")
        #expect(catalog.theme(id: "missing-theme") == .system)
        #expect(catalog.invalidFileCount >= 1)
    }

    @Test func themeIDMustUseTheDocumentedLowercaseSlugShape() throws {
        let valid = try AtlasTheme.decode(JSONEncoder().encode(validTheme()))
        #expect(valid.id == "ocean-test")
        for id in ["x", "Uppercase", "has_underscore", "-leading", String(repeating: "a", count: 49)] {
            let data = try encodedTheme(mutatingID: id)
            var rejected = false
            do {
                _ = try AtlasTheme.decode(data)
            } catch {
                rejected = true
            }
            #expect(rejected)
        }
    }

    private func validTheme() -> AtlasTheme {
        AtlasTheme(
            version: 1,
            id: "ocean-test",
            name: "Test theme",
            light: palette(background: "#F6F9FA"),
            dark: palette(background: "#1C282F")
        )
    }

    private func palette(background: String) -> ThemePalette {
        ThemePalette(background: background, surface: "#27373F", accent: "#6AC8D9",
                     text: "#ECF5F7", secondary: "#ADCAD2", selection: "#24505A")
    }

    private func encodedTheme(mutating field: String) throws -> Data {
        switch field {
        case "unsupported-version": return try encodedTheme(version: 2)
        case "short-id": return try encodedTheme(mutatingID: "x")
        case "invalid-id": return try encodedTheme(mutatingID: "has_underscore")
        case "empty-name": return try encodedTheme(name: "")
        case "long-name": return try encodedTheme(name: String(repeating: "n", count: 61))
        default: return try encodedTheme(color: "#FFF")
        }
    }

    private func encodedTheme(version: Int = 1, name: String = "Test theme", color: String? = nil) throws -> Data {
        var theme = validTheme()
        theme.version = version
        theme.name = name
        if let color { theme.light.accent = color }
        return try JSONEncoder().encode(theme)
    }

    private func encodedTheme(mutatingID id: String) throws -> Data {
        var theme = validTheme()
        theme.id = id
        return try JSONEncoder().encode(theme)
    }
}
