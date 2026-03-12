import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private var appSupportDir: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Osam", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var syncIndexDir: URL {
        let dir = appSupportDir.appendingPathComponent("SyncIndices", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Recent Projects
    private let recentProjectsKey = "osam.recentProjects"

    func loadRecentProjects() -> [URL] {
        guard let bookmarks = defaults.array(forKey: recentProjectsKey) as? [Data] else { return [] }
        return bookmarks.compactMap { data in
            var stale = false
            return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
    }

    func addRecentProject(_ url: URL) {
        var bookmarks = defaults.array(forKey: recentProjectsKey) as? [Data] ?? []
        if let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            bookmarks.removeAll { data in
                var stale = false
                let existing = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                return existing == url
            }
            bookmarks.insert(bookmark, at: 0)
            if bookmarks.count > 20 { bookmarks = Array(bookmarks.prefix(20)) }
            defaults.set(bookmarks, forKey: recentProjectsKey)
        }
    }

    // MARK: - Servers
    private let serversKey = "osam.servers"

    func loadServers() -> [ServerCredential] {
        guard let data = defaults.data(forKey: serversKey) else { return [] }
        return (try? JSONDecoder().decode([ServerCredential].self, from: data)) ?? []
    }

    func saveServers(_ servers: [ServerCredential]) {
        if let data = try? JSONEncoder().encode(servers) {
            defaults.set(data, forKey: serversKey)
        }
    }

    // MARK: - Sync Index
    func loadSyncIndex(projectId: String, serverId: String) -> SyncIndex? {
        let file = syncIndexDir.appendingPathComponent("\(projectId)_\(serverId).json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(SyncIndex.self, from: data)
    }

    func saveSyncIndex(_ index: SyncIndex) {
        let file = syncIndexDir.appendingPathComponent("\(index.projectId)_\(index.serverId).json")
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: file)
        }
    }

    // MARK: - Settings
    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: "osam.settings") else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "osam.settings")
        }
    }
}

struct AppSettings: Codable {
    var darkMode: Bool = true
    var fontSize: CGFloat = 14
    var tabWidth: Int = 4
    var useSpacesForTabs: Bool = true
    var showLineNumbers: Bool = true
    var wordWrap: Bool = false
    var autoSave: Bool = true
    var syncDeleteConfirm: Bool = true
    var fontName: String = "Menlo"
}
