import AppKit
import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasPlayback

struct ReceiverRecordingsView: View {
    @Bindable var store: ReceiverRecordingsStore
    let client: OpenWebifClient?
    let settings: SettingsStore
    let onPlay: () -> Void
    @Environment(\.locale) private var locale
    @State private var showResumeChoice = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Aufnahmen").font(.title2.weight(.semibold))
                Spacer()
                Button("Zurück", systemImage: "chevron.left") { Task { await store.goBack(using: client) } }
                    .disabled(!store.canGoBack || store.isLoading)
                Button("Standardordner", systemImage: "house") { Task { await store.openRoot(using: client) } }
                    .disabled(store.isLoading || client == nil)
                Button("Aktualisieren", systemImage: "arrow.clockwise") {
                    Task {
                        async let recordings: Bool = store.load(using: client, directory: store.currentDirectory)
                        async let storage: Void = store.loadStorage(using: client)
                        async let timers: Void = store.loadTimers(using: client)
                        _ = await (recordings, storage, timers)
                    }
                }.disabled(store.isLoading || store.isLoadingStorage || store.isLoadingTimers || client == nil)
            }.padding(20)
            if let directory = store.currentDirectory {
                Text(directory).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 8)
            }
            if let error = store.error { ErrorNotice(message: settings.language.localized(error)).padding(.horizontal, 20) }
            if let error = store.timerError {
                ErrorNotice(message: settings.language.localized("Timer konnten nicht geladen werden:") + " " + settings.language.localized(error)).padding(.horizontal, 20)
            }
            if let error = store.progressError {
                Text(settings.language.localized(error)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
            }
            storageSummary.padding(.horizontal, 20).padding(.bottom, 10)
            Divider()
            HSplitView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Aufnahmen suchen", text: $store.searchText).textFieldStyle(.roundedBorder)
                    Picker("Aufnahmen", selection: $store.filter) {
                        ForEach(RecordingOverviewFilter.allCases) { filter in Text(LocalizedStringKey(filter.title)).tag(filter) }
                    }.pickerStyle(.segmented)
                    if !store.directories.isEmpty {
                        Menu("Ordner öffnen") {
                            ForEach(store.directories) { directory in
                                Button(directory.name, systemImage: "folder") { Task { await store.open(directory, using: client) } }
                            }
                        }.disabled(store.isLoading)
                    }
                    if (store.isLoading || store.isLoadingTimers) && store.overviewItems.isEmpty {
                        ProgressView("Aufnahmen und Timer werden geladen …").frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(selection: $store.selectedID) {
                            ForEach(store.overviewItems) { item in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.title).font(.headline).lineLimit(2)
                                        Spacer(minLength: 4)
                                        Text(itemStatus(item)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if !item.serviceName.isEmpty { Text(item.serviceName).font(.caption).foregroundStyle(.secondary) }
                                    Text(item.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 4).tag(item.id)
                            }
                        }.overlay {
                            if store.overviewItems.isEmpty && !store.isLoading && !store.isLoadingTimers {
                                ContentUnavailableView("Keine Einträge", systemImage: "film",
                                                       description: Text("Für diesen Filter sind keine Timer oder Aufnahmen verfügbar."))
                            }
                        }
                    }
                }.padding(16).frame(minWidth: 300, idealWidth: 360, maxWidth: 450)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let player = store.player {
                            if let title = store.playingTitle { Text("Wiedergabe: \(title)").font(.headline).lineLimit(2) }
                            PlaybackSurface(slot: player).aspectRatio(16 / 9, contentMode: .fit)
                                .frame(minHeight: 200).clipShape(.rect(cornerRadius: 10))
                            ReceiverRecordingControls(slot: player, stop: { store.stopPlayback() }).id(player.id)
                        }
                        if let selected = store.selectedRecording {
                            Text(selected.title).font(.title2.weight(.semibold))
                            if !selected.serviceName.isEmpty { Text(selected.serviceName).foregroundStyle(.secondary) }
                            if let duration = selected.duration {
                                Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))
                                    .font(.callout).monospacedDigit()
                            }
                            if let size = selected.size { Text(size, format: .byteCount(style: .file)).font(.caption).foregroundStyle(.secondary) }
                            Text(selected.description).font(.callout).textSelection(.enabled)
                            Text("Bibliothekseinträge sind gelistete Dateien. OpenWebif bestätigt hier nicht, dass eine Aufnahme abgeschlossen ist.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let progress = store.savedProgressForSelection {
                                Text("Fortsetzen bei \(Duration.seconds(progress).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("Fortsetzen", systemImage: "play.fill") { showResumeChoice = true }
                                    .buttonStyle(.glassProminent).disabled(client == nil)
                                Button("Von Anfang an abspielen", systemImage: "backward.end.fill") {
                                    Task { await store.play(selected, fromBeginning: true, using: client, settings: settings, onStart: onPlay) }
                                }.disabled(client == nil)
                            } else {
                                Button("Abspielen", systemImage: "play.fill") {
                                    Task { await store.play(selected, using: client, settings: settings, onStart: onPlay) }
                                }.buttonStyle(.glassProminent).disabled(client == nil)
                            }
                        } else if let timer = store.selectedTimer {
                            Label("Timer", systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                            Text(timer.name.isEmpty ? timer.serviceName : timer.name).font(.title2.weight(.semibold))
                            if !timer.serviceName.isEmpty { Text(timer.serviceName).foregroundStyle(.secondary) }
                            Text("\(timer.begin.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))) – \(timer.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
                                .font(.callout)
                            Text(timer.description).font(.callout).textSelection(.enabled)
                            Text("Ein Timer bestätigt keine fertige Aufnahme in der Bibliothek.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if store.player == nil {
                            ContentUnavailableView("Eintrag auswählen", systemImage: "film",
                                                   description: Text("Wähle links einen Timer oder eine Aufnahme aus."))
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minWidth: 380)
            }
        }
        .task(id: client?.profile) {
            async let recordings: Bool = store.load(using: client)
            async let storage: Void = store.loadStorage(using: client)
            async let timers: Void = store.loadTimers(using: client)
            _ = await (recordings, storage, timers)
        }
        .task(id: client?.profile) {
            while !Task.isCancelled, client != nil {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                await store.loadTimers(using: client)
            }
        }
        .confirmationDialog("Wiedergabe fortsetzen?", isPresented: $showResumeChoice, titleVisibility: .visible) {
            Button("Fortsetzen") {
                guard let selected = store.selectedRecording else { return }
                Task { await store.play(selected, using: client, settings: settings, onStart: onPlay) }
            }
            Button("Von Anfang an abspielen") {
                guard let selected = store.selectedRecording else { return }
                Task { await store.play(selected, fromBeginning: true, using: client, settings: settings, onStart: onPlay) }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            if let progress = store.savedProgressForSelection {
                Text("Die letzte Position liegt bei \(Duration.seconds(progress).formatted(.time(pattern: .hourMinuteSecond).locale(locale))).")
            }
        }
        .onDisappear { store.stopPlayback() }
    }

    private func itemStatus(_ item: RecordingOverviewItem) -> String {
        guard case .timer(let timer) = item else { return "Bibliothek" }
        return timer.state == 2 ? "Laufend" : "Geplant"
    }

    @ViewBuilder
    private var storageSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Speicherplatz").font(.headline)
                Spacer()
                if store.isLoadingStorage { ProgressView().controlSize(.small) }
                Button("Speicher aktualisieren", systemImage: "arrow.clockwise") {
                    Task { await store.loadStorage(using: client) }
                }.labelStyle(.iconOnly).help("Speicherplatz aktualisieren").disabled(store.isLoadingStorage || client == nil)
            }
            if let error = store.storageError {
                Text("Speicherinformationen konnten nicht geladen werden: \(settings.language.localized(error))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if store.isLoadingStorage && store.storage.isEmpty {
                Text("Speicherinformationen werden geladen …").font(.caption).foregroundStyle(.secondary)
            } else if store.storage.isEmpty {
                Text("Keine Speicherinformationen verfügbar.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.storage) { disk in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(disk.model ?? settings.language.localized("Laufwerk")).font(.callout.weight(.medium))
                            if disk.containsRecordingDirectory(store.currentDirectory) {
                                Text("Aktueller Ordner liegt auf diesem Laufwerk").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Frei: \(disk.free ?? settings.language.localized("Nicht verfügbar"))").font(.caption).monospacedDigit()
                            Text("Gesamt: \(disk.capacity ?? settings.language.localized("Nicht verfügbar"))").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if let mount = disk.mountPath { Text(mount).font(.caption2).foregroundStyle(.tertiary).textSelection(.enabled) }
                }
            }
        }.padding(10).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReceiverRecordingControls: View {
    let slot: PlaybackSlot
    let stop: () -> Void
    @State private var seekProgress = 0.0
    @State private var isSeeking = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                VStack(spacing: 4) {
                    Slider(value: Binding(get: { isSeeking ? seekProgress : slot.recordingProgress }, set: { seekProgress = $0 }), in: 0...1) { editing in
                        if editing { seekProgress = slot.recordingProgress; isSeeking = true }
                        else { slot.seekRecording(to: seekProgress); isSeeking = false }
                    }.disabled(!slot.canSeekRecording).accessibilityLabel("Wiedergabeposition")
                    if let duration = slot.recordingDuration {
                        HStack {
                            Text(Duration.seconds(duration * slot.recordingProgress).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))
                            Spacer()
                            Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))
                        }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 14) {
                Button(LocalizedStringKey(slot.status == .paused ? "Fortsetzen" : "Pause"), systemImage: slot.status == .paused ? "play.fill" : "pause.fill") {
                    slot.toggleRecordingPause()
                }.disabled(slot.status == .idle || slot.status == .connecting)
                Button("Stoppen", systemImage: "stop.fill", action: stop)
                Slider(value: Binding(get: { slot.volume }, set: { slot.volume = $0 }), in: 0...1)
                    .frame(maxWidth: 130).accessibilityLabel("Lautstärke")
                Spacer()
                Button("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right") { NSApplication.shared.keyWindow?.toggleFullScreen(nil) }
                    .labelStyle(.iconOnly)
            }
        }
    }
}
