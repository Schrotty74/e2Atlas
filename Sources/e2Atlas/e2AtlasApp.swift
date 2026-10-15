import SwiftUI
import AtlasCore
import AtlasThemes

@main
struct E2AtlasApp: App {
    @State private var settings = SettingsStore()
    @State private var themes = ThemeCatalog()
    private let demo = ProcessInfo.processInfo.arguments.contains("--demo")

    var body: some Scene {
        Window("e2Atlas", id: "main") {
            Group {
                if settings.preferences.receivers.isEmpty && !demo {
                    WelcomeView(settings: settings)
                } else {
                    MainWindow(settings: settings, themes: themes, demo: demo)
                }
            }
            .environment(\.atlasTheme, themes.theme(id: settings.preferences.themeID))
            .preferredColorScheme(settings.preferences.appearance == .automatic ? nil : settings.preferences.appearance == .dark ? .dark : .light)
            .task { themes.reload(customDirectory: settings.paths?.support.appendingPathComponent("Themes", isDirectory: true)) }
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                if let url = URL(string: "https://github.com/oe-alliance/OpenWebif") { Link("OpenWebif-Projekt", destination: url) }
            }
        }
        Settings {
            AppSettingsView(settings: settings, themes: themes)
                .environment(\.atlasTheme, themes.theme(id: settings.preferences.themeID))
                .preferredColorScheme(settings.preferences.appearance == .automatic ? nil : settings.preferences.appearance == .dark ? .dark : .light)
        }
    }
}
