import Foundation
import AtlasCore

extension ChannelStore {
    func loadDemo() { setDemoChannels() }
}

extension GuideStore {
    func loadDemo(channels: [Channel]) { setDemoEvents(channels: channels) }
}
