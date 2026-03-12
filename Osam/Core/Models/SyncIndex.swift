import Foundation

struct SyncIndexEntry: Codable, Identifiable {
    var id: String { relativePath }
    let relativePath: String
    var localSize: Int64
    var localModified: Date
    var remoteSize: Int64
    var remoteModified: Date
    var hash: String?
    var lastSyncDirection: SyncDirection
    var lastSyncState: SyncState
    var lastSyncTime: Date

    enum SyncDirection: String, Codable {
        case upload, download, none
    }

    enum SyncState: String, Codable {
        case synced, modified, conflict, deleted
    }
}

struct SyncIndex: Codable {
    var projectId: String
    var serverId: String
    var localRoot: String
    var remoteRoot: String
    var lastFullSync: Date?
    var entries: [String: SyncIndexEntry] // keyed by relativePath

    init(projectId: String, serverId: String, localRoot: String, remoteRoot: String) {
        self.projectId = projectId
        self.serverId = serverId
        self.localRoot = localRoot
        self.remoteRoot = remoteRoot
        self.entries = [:]
    }
}
