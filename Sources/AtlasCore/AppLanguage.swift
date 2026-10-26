import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system, german = "de", english = "en"

    public init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "de" ? .german : .english
    }

    public static func systemLanguage(preferredLanguages: [String]? = nil) -> AppLanguage {
        // An app-specific AppleLanguages override must not redefine the System choice.
        let systemPreferences = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        for preferred in preferredLanguages ?? systemPreferences ?? Locale.preferredLanguages {
            switch Locale(identifier: preferred).language.languageCode?.identifier {
            case "de": return .german
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    public var resolved: AppLanguage { self == .system ? Self.systemLanguage() : self }
    public var locale: Locale { Locale(identifier: resolved.rawValue) }

    /// Resolve AppKit labels and known application messages in the selected bundle language.
    public func localized(_ key: String, bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: resolved.rawValue, ofType: "lproj"), let localizedBundle = Bundle(path: path) else { return key }
        return localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public func resolve(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
