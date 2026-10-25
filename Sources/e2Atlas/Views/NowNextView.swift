import SwiftUI
import AtlasCore

struct NowNextView: View {
    let channels: [Channel]
    let bouquets: [Bouquet]
    @Binding var selectedBouquetID: String?
    @Binding var favoritesOnly: Bool
    @Binding var search: String
    let events: [String: [Programme]]
    let errors: [String: String]
    let isLoading: Bool
    let picons: [String: Data]
    let language: AppLanguage
    let piconRevision: String
    let demo: Bool
    let isMetadataLoading: Bool
    let onPicon: (Channel) async -> Void
    let onProgramme: (Programme, Channel) -> Void
    let onPlay: (Channel) -> Void
    let onRefresh: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            controls
            if channels.isEmpty {
                ContentUnavailableView("Keine Sender", systemImage: "tv", description: Text("Für diese Auswahl sind keine Sender verfügbar."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(channels) { channel in
                            TimelineView(ProgrammeBoundarySchedule(programmes: events[channel.id] ?? [])) { context in
                                channelRow(channel, now: context.date)
                            }
                            .task(id: "\(piconRevision)|\(channel.id)") { if !demo { await onPicon(channel) } }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Bouquet", selection: $selectedBouquetID) {
                ForEach(bouquets) { Text(demo ? language.localized($0.name) : $0.name).tag(Optional($0.id)) }
            }
            .frame(maxWidth: 260)
            .accessibilityLabel("Bouquet")
            .disabled(demo)

            Toggle("Favoriten", systemImage: "star.fill", isOn: $favoritesOnly)
                .toggleStyle(.button)
                .disabled(demo)
            TextField("Sender suchen", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Spacer(minLength: 8)
            if isMetadataLoading { ProgressView().controlSize(.small).accessibilityLabel(Text("Sender werden geladen …")) }
            if isLoading { ProgressView().controlSize(.small).accessibilityLabel(Text("Programmdaten werden geladen …")) }
            Button("Neu laden", systemImage: "arrow.clockwise", action: onRefresh)
                .labelStyle(.iconOnly)
                .help("Sender und Programmdaten neu laden")
                .disabled(demo || isMetadataLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder private func channelRow(_ channel: Channel, now: Date) -> some View {
        let selection = NowNextProgramme.selection(from: events[channel.id] ?? [], at: now)
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 7) {
                PiconView(data: picons[channel.id], name: channel.name, size: 48)
                Text(channel.name).font(.caption.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                Button("Wiedergeben", systemImage: "play.fill") { onPlay(channel) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help(String(format: language.localized("%@ wiedergeben"), channel.name))
                    .accessibilityLabel(Text(String(format: language.localized("%@ wiedergeben"), channel.name)))
                    .disabled(demo)
            }
            .frame(width: 120)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 20) {
                    Group {
                        if let current = selection.current {
                            programmeButton(current, channel: channel, now: now, isCurrent: true)
                        } else {
                            statusLine("Jetzt", value: isLoading ? "Programmdaten werden geladen …" : "Keine aktuelle Sendung verfügbar")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        if let next = selection.next {
                            programmeButton(next, channel: channel, now: now, isCurrent: false)
                        } else {
                            statusLine("Danach", value: "Keine weitere Sendung verfügbar")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error = errors[channel.id] {
                    Label(language.localized(error), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.quaternary.opacity(0.55), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func programmeButton(_ programme: Programme, channel: Channel, now: Date, isCurrent: Bool) -> some View {
        let title = demo ? language.localized(programme.title) : programme.title
        return VStack(alignment: .leading, spacing: 5) {
            Button { onProgramme(programme, channel) } label: {
                VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(isCurrent ? "Jetzt" : "Danach")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(programme.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))–\(programme.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(format: language.localized("%@, %@, %@, %@"), language.localized(isCurrent ? "Jetzt" : "Danach"), channel.name, title, programme.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))))
            .accessibilityHint(Text("Programmdetails öffnen"))
            if isCurrent {
                ProgressView(value: programme.progress(at: now))
                    .accessibilityLabel("Sendungsfortschritt")
                Text("Noch \(Duration.seconds(max(0, programme.end.timeIntervalSince(now))).formatted(.time(pattern: .hourMinute).locale(locale)))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }

    private func statusLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(LocalizedStringKey(title)).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 58, alignment: .leading)
            Text(LocalizedStringKey(value)).font(.callout).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

/// Minute ticks update progress; programme starts and ends are additional exact ticks.
private struct ProgrammeBoundarySchedule: TimelineSchedule {
    let programmes: [Programme]

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(programmes: programmes, start: startDate)
    }

    struct Entries: Sequence, IteratorProtocol {
        let programmes: [Programme]
        let start: Date
        private var previous: Date?

        init(programmes: [Programme], start: Date) { self.programmes = programmes; self.start = start }

        mutating func next() -> Date? {
            guard let previous else { self.previous = start; return start }
            let minute = previous.addingTimeInterval(60)
            let transition = NowNextProgramme.nextTransition(in: programmes, after: previous)
            let next = Swift.min(minute, transition ?? minute)
            self.previous = next
            return next
        }
    }
}
