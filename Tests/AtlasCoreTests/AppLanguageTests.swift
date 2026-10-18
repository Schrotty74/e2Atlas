import Foundation
import Testing
@testable import AtlasCore

private final class LocalizationBundleProbe: NSObject {}

@Suite("Application language")
struct AppLanguageTests {
    @Test func systemUsesFirstSupportedPreferenceAndFallsBackToEnglish() {
        #expect(AppLanguage.systemLanguage(preferredLanguages: ["de-AT", "en"]) == .german)
        #expect(AppLanguage.systemLanguage(preferredLanguages: ["fr-FR", "en-GB", "de"]) == .english)
        #expect(AppLanguage.systemLanguage(preferredLanguages: ["fr", "de-DE"]) == .german)
        #expect(AppLanguage.systemLanguage(preferredLanguages: ["fr"]) == .english)
    }

    @Test func oldSettingsHaveNoOverrideAndLanguageRoundTrips() throws {
        var original = AppPreferences()
        let legacy = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(AppPreferences.self, from: legacy).language == nil)
        original.language = .english
        #expect(try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(original)).language == .english)
        original.language = .german
        #expect(try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(original)).language == .german)
    }

    #if !SWIFT_PACKAGE
    @Test func catalogLookupUsesExplicitLanguageAndLeavesUnknownDataUntouched() {
        let bundle = Bundle(for: LocalizationBundleProbe.self)
        #expect(AppLanguage.english.localized("Fernsehen", bundle: bundle) == "TV")
        #expect(AppLanguage.german.localized("Fernsehen", bundle: bundle) == "Fernsehen")
        #expect(AppLanguage.english.localized("Synthetic user data", bundle: bundle) == "Synthetic user data")
        #expect(AppLanguage.german.locale.language.languageCode?.identifier == "de")
        #expect(AppLanguage.english.locale.language.languageCode?.identifier == "en")
        let message = LocalizedStringResource("In \(15) Minuten Wiedergabe stoppen", bundle: .atURL(bundle.bundleURL))
        #expect(AppLanguage.english.resolve(message) == "Stop playback in 15 minutes")
    }
    #endif
}
