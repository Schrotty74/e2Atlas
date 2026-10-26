import SwiftUI
import AtlasCore

/// Known application keys are looked up at rendering time; receiver and user data use ordinary Text.
struct AppLocalizedText: View {
    private let resource: LocalizedStringResource
    @Environment(\.locale) private var locale

    init(_ key: String) { resource = LocalizedStringResource(stringLiteral: key) }
    init(resource: LocalizedStringResource) { self.resource = resource }

    var body: some View { Text(verbatim: AppLanguage(locale: locale).resolve(resource)) }
}
