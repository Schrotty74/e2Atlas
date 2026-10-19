import Foundation
import Observation
import AtlasCore
import AtlasReceiver

@MainActor @Observable
final class ChannelStore {
    private(set) var bouquets: [Bouquet] = []
    private(set) var channels: [Channel] = []
    private(set) var picons: [String: Data] = [:]
    var selectedBouquetID: String?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var receiverInfo: ReceiverInfo?
    @ObservationIgnored private(set) var client: OpenWebifClient?
    private(set) var metadataRevision = 0
    @ObservationIgnored private let makeClient: (ReceiverProfile, String) -> OpenWebifClient
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var bouquetGeneration = UUID()
    @ObservationIgnored private var lastFailure: AtlasFailure?
    @ObservationIgnored var startupRetryDelays: [Duration] = [.seconds(1), .seconds(3)]

    init(makeClient: @escaping (ReceiverProfile, String) -> OpenWebifClient = {
        OpenWebifClient(profile: $0, password: $1)
    }) { self.makeClient = makeClient }

    func connect(_ profile: ReceiverProfile, password: String, loadMetadata: Bool = true) async {
        generation = UUID()
        bouquets = []; channels = []; picons = [:]; receiverInfo = nil; error = nil
        selectedBouquetID = nil
        client = makeClient(profile, password)
        isLoading = false
        if loadMetadata { await refresh(retryDelays: startupRetryDelays) }
    }

    /// Retry metadata independently of the running stream players.
    func refresh(retryDelays: [Duration]? = nil) async {
        guard let service = client, !isLoading else { return }
        let retryDelays = retryDelays ?? startupRetryDelays
        let token = UUID(); generation = token
        defer { if token == generation { isLoading = false } }
        for attempt in 0...retryDelays.count {
            guard token == generation, !Task.isCancelled else { return }
            error = nil; lastFailure = nil; isLoading = true
            do {
                let info = try await service.verify()
                let list = try await service.bouquets()
                guard token == generation, !Task.isCancelled else { return }
                receiverInfo = info; bouquets = list
                selectedBouquetID = list.first(where: { $0.id == selectedBouquetID })?.id ?? list.first?.id
                if let selected = list.first(where: { $0.id == selectedBouquetID }) {
                    await loadChannels(in: selected)
                } else {
                    channels = []; selectedBouquetID = nil
                    metadataRevision += 1
                }
            } catch is CancellationError { return }
            catch {
                guard token == generation else { return }
                self.error = error.localizedDescription
                lastFailure = error as? AtlasFailure
            }
            guard token == generation, !Task.isCancelled,
                  lastFailure == .unreachable, attempt < retryDelays.count else { return }
            isLoading = true
            do { try await Task.sleep(for: retryDelays[attempt]) } catch { return }
        }
    }
    func loadChannels(in bouquet: Bouquet) async {
        guard let client else { return }
        let token = generation
        let request = UUID(); bouquetGeneration = request
        isLoading = true; error = nil; lastFailure = nil
        do {
            let values = try await client.channels(in: bouquet)
            guard token == generation, request == bouquetGeneration, !Task.isCancelled else { return }
            channels = values; selectedBouquetID = bouquet.id; metadataRevision += 1
        } catch is CancellationError { }
        catch { if token == generation, request == bouquetGeneration { self.error = error.localizedDescription; lastFailure = error as? AtlasFailure } }
        if token == generation, request == bouquetGeneration { isLoading = false }
    }
    func loadPicon(_ channel: Channel) async {
        guard picons[channel.id] == nil, let client else { return }
        let token = generation
        if let data = try? await client.piconData(for: channel), token == generation, !Task.isCancelled { picons[channel.id] = data }
    }
    func setDemoChannels() {
        bouquets = [Bouquet(id: "demo", name: "Beispielsender")]
        selectedBouquetID = "demo"
        channels = ["ORF 2", "Das Erste", "ZDF", "arte", "3sat", "ORF 1"].enumerated().map { Channel(id: "demo-\($0.offset)", name: $0.element, number: $0.offset + 1) }
    }
}
