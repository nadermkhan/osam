import Foundation

struct SyncPlan {
    var uploads: [SyncAction] = []
    var downloads: [SyncAction] = []
    var deletes: [SyncAction] = []
    var conflicts: [SyncConflict] = []
    var skips: [SyncAction] = []

    var totalActions: Int {
        uploads.count + downloads.count + deletes.count + conflicts.count
    }

    var isEmpty: Bool {
        uploads.isEmpty && downloads.isEmpty && deletes.isEmpty && conflicts.isEmpty
    }
}

struct SyncAction: Identifiable {
    let id = UUID()
    let relativePath: String
    let type: ActionType
    let localSize: Int64?
    let remoteSize: Int64?
    let reason: String

    enum ActionType {
        case upload, download, deleteLocal, deleteRemote, skip
    }
}

struct SyncConflict: Identifiable {
    let id = UUID()
    let relativePath: String
    let localModified: Date
    let remoteModified: Date
    let localSize: Int64
    let remoteSize: Int64
    var resolution: ConflictResolution = .skip

    enum ConflictResolution {
        case keepLocal, keepRemote, duplicate, skip
    }
}

struct SyncConfiguration: Hashable {
    let localRoot: URL
    let remoteRoot: String
    let serverId: String
    let direction: SyncDirectionMode

    enum SyncDirectionMode: String, Hashable {
        case localToRemote
        case remoteToLocal
        case twoWay
    }
}

struct SyncProgress {
    var phase: Phase = .idle
    var currentFile: String = ""
    var processedFiles: Int = 0
    var totalFiles: Int = 0
    var bytesTransferred: Int64 = 0

    var fraction: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    enum Phase: String {
        case idle = "Idle"
        case scanning = "Scanning..."
        case comparing = "Comparing..."
        case applying = "Syncing..."
        case finished = "Finished"
        case cancelled = "Cancelled"
        case error = "Error"
    }
}
