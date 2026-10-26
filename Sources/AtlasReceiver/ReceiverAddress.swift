import Foundation
import AtlasCore

public enum ReceiverAddress {
    public static func resolve(_ address: String) throws -> URL {
        let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.contains("@"), !raw.contains("?"), !raw.contains("#") else {
            throw AtlasFailure.invalidAddress
        }
        let candidate = raw.contains("://") ? raw : "http://\(raw)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              (components.port.map { (1...65535).contains($0) } ?? true) else {
            throw AtlasFailure.invalidAddress
        }
        components.path = ""
        guard let url = components.url else { throw AtlasFailure.invalidAddress }
        return url
    }
}
