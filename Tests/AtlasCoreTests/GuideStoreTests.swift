#if !SWIFT_PACKAGE
import Foundation
import Testing
import AtlasCore

@Suite("Guide store query state")
@MainActor
struct GuideStoreTests {
    @Test func changingBouquetDropsOldChannelsFromSearch() async {
        let store = GuideStore()
        let oldBouquet = [Channel(id: "old-1", name: "Old News"), Channel(id: "old-2", name: "Old Sport")]
        let newBouquet = [Channel(id: "new-1", name: "New News")]
        store.setDemoEvents(channels: oldBouquet)
        #expect(!store.searchResults.isEmpty)
        #expect(store.searchResults.allSatisfy { $0.end > store.window.start && $0.start < store.window.end })

        // A nil client models a receiver change while the new bouquet is selected.
        await store.load(channels: newBouquet, client: nil)

        #expect(store.searchResults.isEmpty)
    }
}
#endif
