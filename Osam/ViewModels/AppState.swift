import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var settings: AppSettings
    @Published var servers: [ServerCredential]
    @Published var recentProjects: [URL]

    private let persistence = PersistenceManager.shared

    init() {
        self.settings = PersistenceManager.shared.loadSettings()
        self.servers = PersistenceManager.shared.loadServers()
        self.recentProjects = PersistenceManager.shared.loadRecentProjects()
    }

    func saveSettings() {
        persistence.saveSettings(settings)
    }

    func saveServer(_ server: ServerCredential, password: String) {
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
        } else {
            servers.append(server)
        }
        persistence.saveServers(servers)
        try? KeychainManager.shared.save(password: password, forKey: server.keychainKey)
    }

    func deleteServer(_ server: ServerCredential) {
        servers.removeAll { $0.id == server.id }
        persistence.saveServers(servers)
        KeychainManager.shared.delete(key: server.keychainKey)
    }

    func addRecentProject(_ url: URL) {
        persistence.addRecentProject(url)
        recentProjects = persistence.loadRecentProjects()
    }
}
