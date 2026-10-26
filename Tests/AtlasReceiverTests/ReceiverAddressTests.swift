import Foundation
import Testing
@testable import AtlasReceiver
import AtlasCore

@Suite("Receiver address resolution")
struct ReceiverAddressTests {
    @Test(arguments: [
        ("receiver.local", "http", "receiver.local", nil as Int?),
        ("https://receiver.local:8443", "https", "receiver.local", 8443 as Int?),
        ("192.0.2.10:80", "http", "192.0.2.10", 80 as Int?)
    ])
    func resolvesSupportedAddresses(input: String, scheme: String, host: String, port: Int?) throws {
        let url = try ReceiverAddress.resolve(input)
        #expect(url.scheme == scheme)
        #expect(url.host == host)
        #expect(url.port == port)
        #expect(url.user == nil)
        #expect(url.password == nil)
    }

    @Test(arguments: [
        "",
        "receiver.local/path",
        "http://user:secret@receiver.local",
        "receiver.local?password=secret",
        "ftp://receiver.local",
        "http://receiver.local:70000"
    ])
    func rejectsAddressesThatCouldChangeRequestScope(input: String) {
        #expect(throws: AtlasFailure.invalidAddress) {
            try ReceiverAddress.resolve(input)
        }
    }
}
