import Foundation

actor SyncEngine {
    private let localFileManager = LocalFileManager.shared
    private let persistence = PersistenceManager.shared

    private(set) var progress = SyncProgress()
    private var isCancelled = false

    func cancel() {
        isCancelled = true
        progress.phase = .cancelled
    }

    func reset() {
        isCancelled = false
        progress = SyncProgress()
    }

    // MARK: - Plan (Dry Run)

    func planSync(
        config: SyncConfiguration,
        ftpService: FTPServiceProtocol
    ) async throws -> SyncPlan {
        isCancelled = false
        progress = SyncProgress(phase: .scanning)

        // Load existing sync index
        let projectId = config.localRoot.lastPathComponent
        let syncIndex = persistence.loadSyncIndex(projectId: projectId, serverId: config.serverId)
            ?? SyncIndex(projectId: projectId, serverId: config.serverId,
                        localRoot: config.localRoot.path, remoteRoot: config.remoteRoot)

        // Scan local files
        progress.phase = .scanning
        let localFiles = try localFileManager.recursiveList(of: config.localRoot, relativeTo: config.localRoot)

        guard !isCancelled else { throw SyncError.cancelled }

        // Scan remote files
        let remoteItems = try await ftpService.recursiveList(path: config.remoteRoot)
        let remoteFiles = remoteItems.filter { !$0.isDirectory }.map { item -> FileMetadata in
            let relativePath = item.path
                .replacingOccurrences(of: config.remoteRoot, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return FileMetadata(
                relativePath: relativePath,
                size: item.size,
                modified: item.modified,
                isDirectory: false
            )
        }

        guard !isCancelled else { throw SyncError.cancelled }

        // Build maps
        progress.phase = .comparing
        let localMap = Dictionary(localFiles.map { ($0.relativePath, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteMap = Dictionary(remoteFiles.map { ($0.relativePath, $0) }, uniquingKeysWith: { first, _ in first })

        let allPaths = Set(localMap.keys).union(Set(remoteMap.keys))

        var plan = SyncPlan()

        for path in allPaths {
            guard !isCancelled else { throw SyncError.cancelled }

            let local = localMap[path]
            let remote = remoteMap[path]
            let indexEntry = syncIndex.entries[path]

            switch config.direction {
            case .localToRemote:
                if let local = local {
                    if let remote = remote {
                        // Both exist
                        if let entry = indexEntry {
                            if local.size != entry.localSize || local.modified > entry.lastSyncTime {
                                // Local changed since last sync
                                plan.uploads.append(SyncAction(
                                    relativePath: path, type: .upload,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Local file modified"
                                ))
                            } else {
                                plan.skips.append(SyncAction(
                                    relativePath: path, type: .skip,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Unchanged"
                                ))
                            }
                        } else {
                            // No previous sync - compare metadata
                            if local.size != remote.size || abs(local.modified.timeIntervalSince(remote.modified)) > 2 {
                                plan.uploads.append(SyncAction(
                                    relativePath: path, type: .upload,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Files differ"
                                ))
                            } else {
                                plan.skips.append(SyncAction(
                                    relativePath: path, type: .skip,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Identical"
                                ))
                            }
                        }
                    } else {
                        // Only local exists
                        plan.uploads.append(SyncAction(
                            relativePath: path, type: .upload,
                            localSize: local.size, remoteSize: nil,
                            reason: "New local file"
                        ))
                    }
                } else {
                    // Only remote exists - in local-to-remote mode, could delete remote
                    if indexEntry != nil {
                        plan.deletes.append(SyncAction(
                            relativePath: path, type: .deleteRemote,
                            localSize: nil, remoteSize: remote?.size,
                            reason: "Deleted locally"
                        ))
                    }
                }

            case .remoteToLocal:
                if let remote = remote {
                    if let local = local {
                        if let entry = indexEntry {
                            if remote.size != entry.remoteSize || remote.modified > entry.lastSyncTime {
                                plan.downloads.append(SyncAction(
                                    relativePath: path, type: .download,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Remote file modified"
                                ))
                            } else {
                                plan.skips.append(SyncAction(
                                    relativePath: path, type: .skip,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Unchanged"
                                ))
                            }
                        } else {
                            if local.size != remote.size || abs(local.modified.timeIntervalSince(remote.modified)) > 2 {
                                plan.downloads.append(SyncAction(
                                    relativePath: path, type: .download,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Files differ"
                                ))
                            } else {
                                plan.skips.append(SyncAction(
                                    relativePath: path, type: .skip,
                                    localSize: local.size, remoteSize: remote.size,
                                    reason: "Identical"
                                ))
                            }
                        }
                    } else {
                        plan.downloads.append(SyncAction(
                            relativePath: path, type: .download,
                            localSize: nil, remoteSize: remote.size,
                            reason: "New remote file"
                        ))
                    }
                } else {
                    if indexEntry != nil {
                        plan.deletes.append(SyncAction(
                            relativePath: path, type: .deleteLocal,
                            localSize: local?.size, remoteSize: nil,
                            reason: "Deleted remotely"
                        ))
                    }
                }

            case .twoWay:
                if let local = local, let remote = remote {
                    if let entry = indexEntry {
                        let localChanged = local.size != entry.localSize || local.modified > entry.lastSyncTime
                        let remoteChanged = remote.size != entry.remoteSize || remote.modified > entry.lastSyncTime

                        if localChanged && remoteChanged {
                            plan.conflicts.append(SyncConflict(
                                relativePath: path,
                                localModified: local.modified,
                                remoteModified: remote.modified,
                                localSize: local.size,
                                remoteSize: remote.size
                            ))
                        } else if localChanged {
                            plan.uploads.append(SyncAction(
                                relativePath: path, type: .upload,
                                localSize: local.size, remoteSize: remote.size,
                                reason: "Local modified"
                            ))
                        } else if remoteChanged {
                            plan.downloads.append(SyncAction(
                                relativePath: path, type: .download,
                                localSize: local.size, remoteSize: remote.size,
                                reason: "Remote modified"
                            ))
                        } else {
                            plan.skips.append(SyncAction(
                                relativePath: path, type: .skip,
                                localSize: local.size, remoteSize: remote.size,
                                reason: "Unchanged"
                                ))
                        }
                    } else {
                        // First sync - compare
                        if local.size != remote.size || abs(local.modified.timeIntervalSince(remote.modified)) > 2 {
                            plan.conflicts.append(SyncConflict(
                                relativePath: path,
                                localModified: local.modified,
                                remoteModified: remote.modified,
                                localSize: local.size,
                                remoteSize: remote.size
                            ))
                        } else {
                            plan.skips.append(SyncAction(
                                relativePath: path, type: .skip,
                                localSize: local.size, remoteSize: remote.size,
                                reason: "Identical"
                            ))
                        }
                    }
                } else if let local = local {
                    if let entry = indexEntry {
                        // Was synced before, now missing remotely - conflict or delete
                        plan.conflicts.append(SyncConflict(
                            relativePath: path,
                            localModified: local.modified,
                            remoteModified: entry.remoteModified,
                            localSize: local.size,
                            remoteSize: 0
                        ))
                    } else {
                        plan.uploads.append(SyncAction(
                            relativePath: path, type: .upload,
                            localSize: local.size, remoteSize: nil,
                            reason: "New local file"
                        ))
                    }
                } else if let remote = remote {
                    if let entry = indexEntry {
                        plan.conflicts.append(SyncConflict(
                            relativePath: path,
                            localModified: entry.localModified,
                            remoteModified: remote.modified,
                            localSize: 0,
                            remoteSize: remote.size
                        ))
                    } else {
                        plan.downloads.append(SyncAction(
                            relativePath: path, type: .download,
                            localSize: nil, remoteSize: remote.size,
                            reason: "New remote file"
                        ))
                    }
                }
            }
        }

        progress.phase = .idle
        return plan
    }

    // MARK: - Apply

    func applySync(
        plan: SyncPlan,
        config: SyncConfiguration,
        ftpService: FTPServiceProtocol
    ) async throws {
        isCancelled = false
        progress = SyncProgress(phase: .applying, totalFiles: plan.uploads.count + plan.downloads.count + plan.deletes.count + plan.conflicts.count)

        let projectId = config.localRoot.lastPathComponent
        var syncIndex = persistence.loadSyncIndex(projectId: projectId, serverId: config.serverId)
            ?? SyncIndex(projectId: projectId, serverId: config.serverId,
                        localRoot: config.localRoot.path, remoteRoot: config.remoteRoot)

        // Process uploads
        for action in plan.uploads {
            guard !isCancelled else { throw SyncError.cancelled }
            progress.currentFile = action.relativePath

            let localURL = config.localRoot.appendingPathComponent(action.relativePath)
            let remotePath = config.remoteRoot.hasSuffix("/")
                ? config.remoteRoot + action.relativePath
                : config.remoteRoot + "/" + action.relativePath

            // Ensure remote directory exists
            let remoteDir = (remotePath as NSString).deletingLastPathComponent
            try? await ftpService.createDirectory(remotePath: remoteDir)

            try await ftpService.uploadFile(localURL: localURL, remotePath: remotePath)

            // Update sync index
            let localAttrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
            syncIndex.entries[action.relativePath] = SyncIndexEntry(
                relativePath: action.relativePath,
                localSize: action.localSize ?? 0,
                localModified: (localAttrs?[.modificationDate] as? Date) ?? Date(),
                remoteSize: action.localSize ?? 0,
                remoteModified: Date(),
                lastSyncDirection: .upload,
                lastSyncState: .synced,
                lastSyncTime: Date()
            )

            progress.processedFiles += 1
        }

        // Process downloads
        for action in plan.downloads {
            guard !isCancelled else { throw SyncError.cancelled }
            progress.currentFile = action.relativePath

            let localURL = config.localRoot.appendingPathComponent(action.relativePath)
            let remotePath = config.remoteRoot.hasSuffix("/")
                ? config.remoteRoot + action.relativePath
                : config.remoteRoot + "/" + action.relativePath

            // Ensure local directory exists
            let localDir = localURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)

            try await ftpService.downloadFile(remotePath: remotePath, localURL: localURL)

            let localAttrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
            syncIndex.entries[action.relativePath] = SyncIndexEntry(
                relativePath: action.relativePath,
                localSize: (localAttrs?[.size] as? Int64) ?? 0,
                localModified: (localAttrs?[.modificationDate] as? Date) ?? Date(),
                remoteSize: action.remoteSize ?? 0,
                remoteModified: Date(),
                lastSyncDirection: .download,
                lastSyncState: .synced,
                lastSyncTime: Date()
            )

            progress.processedFiles += 1
        }

        // Process deletes
        for action in plan.deletes {
            guard !isCancelled else { throw SyncError.cancelled }
            progress.currentFile = action.relativePath

            switch action.type {
            case .deleteLocal:
                let localURL = config.localRoot.appendingPathComponent(action.relativePath)
                try? FileManager.default.removeItem(at: localURL)
            case .deleteRemote:
                let remotePath = config.remoteRoot.hasSuffix("/")
                    ? config.remoteRoot + action.relativePath
                    : config.remoteRoot + "/" + action.relativePath
                try? await ftpService.deleteFile(remotePath: remotePath)
            default: break
            }

            syncIndex.entries.removeValue(forKey: action.relativePath)
            progress.processedFiles += 1
        }

        // Process resolved conflicts
        for conflict in plan.conflicts {
            guard !isCancelled else { throw SyncError.cancelled }
            progress.currentFile = conflict.relativePath

            let localURL = config.localRoot.appendingPathComponent(conflict.relativePath)
            let remotePath = config.remoteRoot.hasSuffix("/")
                ? config.remoteRoot + conflict.relativePath
                : config.remoteRoot + "/" + conflict.relativePath

            switch conflict.resolution {
            case .keepLocal:
                try await ftpService.uploadFile(localURL: localURL, remotePath: remotePath)
            case .keepRemote:
                try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await ftpService.downloadFile(remotePath: remotePath, localURL: localURL)
            case .duplicate:
                // Download remote with suffix
                let ext = localURL.pathExtension
                let base = localURL.deletingPathExtension().lastPathComponent
                let duplicateURL = localURL.deletingLastPathComponent()
                    .appendingPathComponent("\(base)_remote.\(ext)")
                try await ftpService.downloadFile(remotePath: remotePath, localURL: duplicateURL)
                // Upload local
                try await ftpService.uploadFile(localURL: localURL, remotePath: remotePath)
            case .skip:
                break
            }

            let localAttrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
            syncIndex.entries[conflict.relativePath] = SyncIndexEntry(
                relativePath: conflict.relativePath,
                localSize: (localAttrs?[.size] as? Int64) ?? 0,
                localModified: (localAttrs?[.modificationDate] as? Date) ?? Date(),
                remoteSize: conflict.remoteSize,
                remoteModified: Date(),
                lastSyncDirection: conflict.resolution == .keepRemote ? .download : .upload,
                lastSyncState: .synced,
                lastSyncTime: Date()
            )

            progress.processedFiles += 1
        }

        // Save sync index
        syncIndex.lastFullSync = Date()
        persistence.saveSyncIndex(syncIndex)

        progress.phase = .finished
    }

    enum SyncError: LocalizedError {
        case cancelled
        case scanFailed(String)
        case transferFailed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Sync cancelled"
            case .scanFailed(let msg): return "Scan failed: \(msg)"
            case .transferFailed(let msg): return "Transfer failed: \(msg)"
            }
        }
    }
}
