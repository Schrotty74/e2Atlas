import AppKit
import SwiftUI
import AtlasCore
import AtlasThemes

@main
struct E2AtlasApp: App {
    @State private var settings: SettingsStore
    @State private var themes = ThemeCatalog()
    @State private var reminders: ProgrammeReminderStore
    @Environment(\.openWindow) private var openWindow
    private let demo = ProcessInfo.processInfo.arguments.contains("--demo")

    init() {
        let initialSettings = SettingsStore()
        let initialReminders = ProgrammeReminderStore()
        // Install the notification delegate during app initialization, before a cold-launch response arrives.
        initialReminders.configure(fileURL: initialSettings.paths?.support.appendingPathComponent("reminders.json"))
        initialReminders.retainReceivers(Set(initialSettings.preferences.receivers.map(\.id)))
        _settings = State(initialValue: initialSettings)
        _reminders = State(initialValue: initialReminders)
    }

    var body: some Scene {
        Window("e2Atlas", id: "main") {
            Group {
                if settings.preferences.receivers.isEmpty && !demo {
                    WelcomeView(settings: settings)
                } else {
                    MainWindow(settings: settings, themes: themes, demo: demo, reminders: reminders)
                }
            }
            .background(MainWindowCloseHandler())
            .environment(\.locale, settings.language.locale)
            .environment(\.atlasTheme, themes.theme(id: settings.preferences.themeID))
            .preferredColorScheme(settings.preferences.appearance == .automatic ? nil : settings.preferences.appearance == .dark ? .dark : .light)
            .task {
                reminders.configure(fileURL: settings.paths?.support.appendingPathComponent("reminders.json"))
                reminders.retainReceivers(Set(settings.preferences.receivers.map(\.id)))
            }
            .onChange(of: settings.preferences.receivers.map(\.id)) { _, ids in reminders.retainReceivers(Set(ids)) }
            .task { themes.reload(customDirectory: settings.paths?.support.appendingPathComponent("Themes", isDirectory: true)) }
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu(settings.language.localized("Receiver")) {
                Button(settings.language.localized("Receiver-Info …"), systemImage: "info.circle") { openWindow(id: "receiver-info") }
                    .disabled(settings.selectedReceiver == nil)
            }
            CommandMenu(settings.language.localized("Sprache")) {
                Picker(settings.language.localized("Sprache"), selection: Binding(
                    get: { settings.language },
                    set: { settings.setLanguage($0) }
                )) {
                    Text(verbatim: settings.language.localized("System")).tag(AppLanguage.system)
                    Text(verbatim: "Deutsch").tag(AppLanguage.german)
                    Text(verbatim: "English").tag(AppLanguage.english)
                }.pickerStyle(.inline)
            }
            CommandGroup(replacing: .help) {
                if let url = URL(string: "https://github.com/Schrotty74/e2Atlas") { Link(settings.language.localized("e2Atlas auf GitHub"), destination: url) }
                if let url = URL(string: "https://schrotty74.github.io/Portfolio/") { Link(settings.language.localized("Homepage"), destination: url) }
                Divider()
                if let url = URL(string: "https://github.com/oe-alliance/OpenWebif") { Link(settings.language.localized("OpenWebif-Projekt"), destination: url) }
            }
        }
        Window(settings.language.localized("Receiver-Info"), id: "receiver-info") {
            ReceiverInfoView(settings: settings)
                .environment(\.locale, settings.language.locale)
                .environment(\.atlasTheme, themes.theme(id: settings.preferences.themeID))
                .preferredColorScheme(settings.preferences.appearance == .automatic ? nil : settings.preferences.appearance == .dark ? .dark : .light)
        }
        .defaultSize(width: 620, height: 720)
        .windowResizability(.contentMinSize)
        Settings {
            AppSettingsView(settings: settings, themes: themes)
                .environment(\.locale, settings.language.locale)
                .environment(\.atlasTheme, themes.theme(id: settings.preferences.themeID))
                .preferredColorScheme(settings.preferences.appearance == .automatic ? nil : settings.preferences.appearance == .dark ? .dark : .light)
        }
    }
}


/// Observe only the main scene's window; leave auxiliary windows independent.
private struct MainWindowCloseHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowCloseObserver { MainWindowCloseObserver() }
    func updateNSView(_ nsView: MainWindowCloseObserver, context: Context) { }
}

private final class MainWindowCloseObserver: NSView {
    private var closeObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeCloseObserver()
        guard let window else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.removeCloseObserver()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func removeCloseObserver() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
    }

    isolated deinit { removeCloseObserver() }
}
