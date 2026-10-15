import SwiftUI
import AtlasCore
import AtlasReceiver

struct WelcomeView: View {
    let settings: SettingsStore
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "play.rectangle.on.rectangle.fill").font(.system(size: 56)).foregroundStyle(.tint).padding(.top, 24)
                VStack(spacing: 8) {
                    Text("Willkommen bei e2Atlas").font(.largeTitle.weight(.semibold))
                    Text("Verbinde deinen Enigma2-Receiver und sieh fern auf deinem Mac.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if let error = settings.error { ErrorNotice(message: error) }
                ReceiverEditor(settings: settings, profile: nil, onSaved: {})
                Text("Du kannst bis zu drei Receiver einrichten. Weitere Geräte fügst du später in den Einstellungen hinzu.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(32).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .frame(minWidth: 620, minHeight: 680)
    }
}

struct ReceiverEditor: View {
    let settings: SettingsStore
    let profile: ReceiverProfile?
    let onSaved: () -> Void
    @State private var name: String
    @State private var address: String
    @State private var username: String
    @State private var password = ""
    @State private var port: Int
    @State private var busy = false
    @State private var message: String?
    @State private var operation: Task<Void, Never>?
    @State private var id: UUID
    @State private var operationID = UUID()

    init(settings: SettingsStore, profile: ReceiverProfile?, onSaved: @escaping () -> Void) {
        self.settings = settings; self.profile = profile; self.onSaved = onSaved
        id = profile?.id ?? UUID()
        name = profile?.name ?? ""; address = profile?.address ?? ""; username = profile?.username ?? ""; port = profile?.streamPort ?? 8001
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                TextField("Receiver-Name", text: $name, prompt: Text("z. B. Wohnzimmer"))
                TextField("IP-Adresse oder Hostname", text: $address, prompt: Text("Adresse deines Receivers"))
                    .autocorrectionDisabled()
                TextField("Benutzername", text: $username).autocorrectionDisabled()
                SecureField("Passwort", text: $password)
                DisclosureGroup("Weitere Einstellungen") {
                    TextField("Streaming-Port", value: $port, format: .number.grouping(.never))
                    Text("Standard: 8001. Die Web-Adresse kann einen eigenen Port enthalten.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(busy)
            Label("Dein Passwort wird im macOS-Schlüsselbund gespeichert.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
            if let message { ErrorNotice(message: message) }
            HStack {
                if busy {
                    ProgressView().controlSize(.small)
                    Text("Verbindung wird geprüft …").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Abbrechen") { operation?.cancel(); busy = false }
                } else {
                    Spacer()
                    Button("Verbinden und speichern", action: connect)
                        .buttonStyle(.glassProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .task {
            if let profile {
                do { password = try settings.credentials.password(for: profile.id) }
                catch { message = error.localizedDescription }
            }
        }
        .onDisappear { operation?.cancel(); password = "" }
    }

    private func connect() {
        message = nil
        guard (1...65535).contains(port) else { message = "Bitte einen Streaming-Port zwischen 1 und 65535 wählen."; return }
        do { _ = try ReceiverAddress.resolve(address) } catch { message = error.localizedDescription; return }
        let value = ReceiverProfile(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), address: address.trimmingCharacters(in: .whitespacesAndNewlines), username: username, streamPort: port)
        let secret = password
        busy = true
        operation?.cancel()
        let token = UUID(); operationID = token
        operation = Task {
            do {
                _ = try await OpenWebifClient(profile: value, password: secret).verify()
                try Task.checkCancellation()
                guard token == operationID else { return }
                try settings.saveReceiver(value, password: secret)
                password = ""; busy = false; onSaved()
            } catch is CancellationError { if token == operationID { busy = false } }
            catch { if token == operationID { message = error.localizedDescription; busy = false } }
        }
    }
}

struct ReceiverManagementView: View {
    let settings: SettingsStore
    @State private var editing: ReceiverProfile?
    @State private var adding = false
    @State private var deleteTarget: ReceiverProfile?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Deine Receiver").font(.title2.weight(.semibold))
                Spacer()
                Text("\(settings.preferences.receivers.count) von 3").foregroundStyle(.secondary)
            }
            ForEach(settings.preferences.receivers) { receiver in
                HStack(spacing: 12) {
                    Image(systemName: "tv").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) { Text(receiver.name).font(.headline); Text(receiver.address).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Bearbeiten") { editing = receiver }
                    Button("Entfernen", systemImage: "trash", role: .destructive) { deleteTarget = receiver }.labelStyle(.iconOnly)
                }.padding(14).background(.quaternary, in: .rect(cornerRadius: 12))
            }
            if let error { ErrorNotice(message: error) }
            Button("Receiver hinzufügen", systemImage: "plus") { adding = true }
                .disabled(settings.preferences.receivers.count >= 3)
            Spacer(minLength: 0)
        }
        .padding(24).frame(width: 570, height: 390)
        .sheet(isPresented: $adding) { ReceiverEditor(settings: settings, profile: nil, onSaved: { adding = false }).padding(24).frame(width: 570) }
        .sheet(item: $editing) { profile in ReceiverEditor(settings: settings, profile: profile, onSaved: { editing = nil }).padding(24).frame(width: 570) }
        .confirmationDialog("Receiver entfernen?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                if let target = deleteTarget {
                    do { try settings.removeReceiver(target.id) } catch { self.error = error.localizedDescription }
                }
                deleteTarget = nil
            }
        } message: { Text("Das Profil und sein gespeichertes Passwort werden entfernt.") }
    }
}
