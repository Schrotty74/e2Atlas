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
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var bouquetGeneration = UUID()

    func connect(_ profile: ReceiverProfile, password: String) async {
        let token = UUID(); generation = token
        bouquets = []; channels = []; picons = [:]; receiverInfo = nil; error = nil; isLoading = true
        let service = OpenWebifClient(profile: profile, password: password); client = service
        do {
            let info = try await service.verify()
            let list = try await service.bouquets()
            guard token == generation, !Task.isCancelled else { return }
            receiverInfo = info; bouquets = list; selectedBouquetID = list.first?.id
            if let first = list.first { await loadChannels(in: first) }
        } catch is CancellationError { }
        catch { if token == generation { self.error = error.localizedDescription } }
        if token == generation { isLoading = false }
    }
    func loadChannels(in bouquet: Bouquet) async {
        guard let client else { return }
        let token = generation
        let request = UUID(); bouquetGeneration = request
        isLoading = true; error = nil
        do {
            let values = try await client.channels(in: bouquet)
            guard token == generation, request == bouquetGeneration, !Task.isCancelled else { return }
            channels = values; selectedBouquetID = bouquet.id
        } catch is CancellationError { }
        catch { if token == generation, request == bouquetGeneration { self.error = error.localizedDescription } }
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
