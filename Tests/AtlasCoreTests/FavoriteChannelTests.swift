import Foundation
import Testing
@testable import AtlasCore

@Suite("Receiver favourites")
struct FavoriteChannelTests {
    @Test func favouritesPersistOutsideBouquetAndStayReceiverScoped() throws {
        var prefs = AppPreferences()
        let first = ReceiverProfile(name: "One", address: "one.test")
        let second = ReceiverProfile(name: "Two", address: "two.test")
        try prefs.upsert(first); try prefs.upsert(second)
        let channel = Channel(id: "channel", name: "Example")
        prefs.toggleFavorite(channel, receiverID: first.id)
        #expect(prefs.isFavorite(channel, receiverID: first.id))
        #expect(!prefs.isFavorite(channel, receiverID: second.id))
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(prefs))
        #expect(restored.favoriteChannels?.first?.channel == channel)
        prefs.toggleFavorite(channel, receiverID: first.id)
        #expect(!prefs.isFavorite(channel, receiverID: first.id))
        prefs.toggleFavorite(channel, receiverID: second.id)
        prefs.removeReceiver(id: second.id)
        #expect(prefs.favoriteChannels?.isEmpty == true)
    }
    @Test func refusesFavouritesForUnconfiguredReceiver() {
        var prefs = AppPreferences()
        prefs.toggleFavorite(Channel(id: "channel", name: "Example"), receiverID: UUID())
        #expect((prefs.favoriteChannels ?? []).isEmpty)
    }
}
