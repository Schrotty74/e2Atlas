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

    @Test func acceptsLegacyPaletteAndRejectsInvalidGradient() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(validTheme())) as? [String: Any])
        var light = try #require(object["light"] as? [String: Any])
        light.removeValue(forKey: "backgroundEnd")
        object["light"] = light
        #expect(try AtlasTheme.decode(JSONSerialization.data(withJSONObject: object)).light.backgroundEnd == nil)
        light["backgroundEnd"] = "#XYZ123"
        object["light"] = light
        #expect(throws: (any Error).self) { try AtlasTheme.decode(JSONSerialization.data(withJSONObject: object)) }
    }

    @Test @MainActor func loadsOceanAndSeveralCustomThemesWithReservedIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("e2Atlas-Themes-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var first = validTheme(); first.id = "custom-first"; first.name = "First"
        var second = validTheme(); second.id = "custom-second"; second.name = "Second"
        try JSONEncoder().encode(first).write(to: directory.appendingPathComponent("a.json"))
        try JSONEncoder().encode(second).write(to: directory.appendingPathComponent("b.json"))
        first.name = "Duplicate"
        try JSONEncoder().encode(first).write(to: directory.appendingPathComponent("c.json"))
        first.id = "ocean"
        try JSONEncoder().encode(first).write(to: directory.appendingPathComponent("ocean.json"))
        let catalog = ThemeCatalog()
        catalog.reload(customDirectory: directory)
        #expect(catalog.theme(id: "ocean").name == "Ocean")
        #expect(catalog.theme(id: "ocean").dark.backgroundEnd != nil)
        #expect(catalog.theme(id: "custom-first").name == "First")
        #expect(catalog.theme(id: "custom-second").name == "Second")
        #expect(catalog.invalidFileCount == 2)
        #expect(!catalog.themes.contains { $0.id == "mein-theme" }, "Bundled template must not be a built-in theme")
        try FileManager.default.removeItem(at: directory.appendingPathComponent("b.json"))
        catalog.reload(customDirectory: directory)
        #expect(catalog.theme(id: "custom-second") == .system)
    }

    @Test @MainActor func exportsEditableTemplatesWithoutOverwritingExistingFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("e2Atlas-Template-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = ThemeCatalog()
        catalog.reload(customDirectory: directory)
        let first = try catalog.createTemplate(in: directory)
        let original = try Data(contentsOf: first.url)
        let second = try catalog.createTemplate(in: directory)
        #expect(first.url != second.url)
        #expect(first.theme.id != second.theme.id)
        #expect(try Data(contentsOf: first.url) == original)
        #expect(try AtlasTheme.decode(original).light.backgroundEnd != nil)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Theme-README.md").path))
        let germanGuide = try Data(contentsOf: directory.appendingPathComponent("Theme-README.md"))
        let english = try catalog.createTemplate(in: directory, language: "en")
        #expect(english.theme.name.hasPrefix("My theme"))
        let englishGuide = try String(contentsOf: directory.appendingPathComponent("Theme-README.en.md"), encoding: .utf8)
        #expect(englishGuide.contains("backgroundEnd"))
        #expect(englishGuide.contains("Open theme folder"))
        #expect(try Data(contentsOf: directory.appendingPathComponent("Theme-README.md")) == germanGuide)
        catalog.reload(customDirectory: directory)
        #expect(catalog.theme(id: first.theme.id) == first.theme)
        #expect(catalog.theme(id: second.theme.id) == second.theme)
    }

    @Test @MainActor func warmThemesProvideDistinctValidLightAndDarkPalettes() throws {
        let catalog = ThemeCatalog()
        catalog.reload(customDirectory: nil)
        for id in ["ivory", "bronze"] {
            let theme = catalog.theme(id: id)
            #expect(theme.id == id)
            #expect(theme.light != theme.dark)
            #expect(theme.light.backgroundEnd != nil)
            #expect(theme.dark.backgroundEnd != nil)
            #expect(try AtlasTheme.decode(JSONEncoder().encode(theme)) == theme)
        }
        #expect(catalog.theme(id: "ivory").light.background == "#FBF8F3")
        #expect(catalog.theme(id: "ivory").light != catalog.theme(id: "bronze").light)
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
