import Foundation

struct ServerCredential: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var label: String
    var host: String
    var port: Int
    var username: String
    var useFTPS: Bool
    var initialPath: String
    var lastConnected: Date?

    // Password stored in Keychain, not in this struct
    var keychainKey: String {
        "osam.ftp.\(id)"
    }

    static var defaultPort: Int { 21 }

    init(label: String = "", host: String = "", port: Int = 21,
         username: String = "", useFTPS: Bool = false, initialPath: String = "/") {
        self.label = label
        self.host = host
        self.port = port
        self.username = username
        self.useFTPS = useFTPS
        self.initialPath = initialPath
    }
}
