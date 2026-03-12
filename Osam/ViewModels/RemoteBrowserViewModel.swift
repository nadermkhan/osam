import SwiftUI

@MainActor
final class RemoteBrowserViewModel: ObservableObject {
    @Published var currentPath = "/"
    @Published var files: [RemoteFileItem] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var pathHistory: [String] = ["/"]

    let serverId: String
    let ftpService: FTPService

    private var credential: ServerCredential?

    init(serverId: String) {
        self.serverId = serverId
        self.ftpService = FTPService()
    }

    func connect(credential: ServerCredential) async {
        self.credential = credential
        isLoading = true
        errorMessage = nil
        do {
            let password = KeychainManager.shared.load(key: credential.keychainKey) ?? ""
            try await ftpService.connect(credential: credential, password: password)
            isConnected = true
            currentPath = credential.initialPath
            await loadDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadDirectory() async {
        isLoading = true
        errorMessage = nil
        do {
            let items = try await ftpService.listDirectory(path: currentPath)
            files = items.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func navigateInto(_ item: RemoteFileItem) async {
        guard item.isDirectory else { return }
        pathHistory.append(currentPath)
        currentPath = item.path
        await loadDirectory()
    }

    func navigateUp() async {
        guard let previous = pathHistory.popLast() else { return }
        currentPath = previous
        await loadDirectory()
    }

    func downloadFile(_ item: RemoteFileItem, to localURL: URL) async throws {
        try await ftpService.downloadFile(remotePath: item.path, localURL: localURL)
    }

    func uploadFile(localURL: URL, remotePath: String) async throws {
        try await ftpService.uploadFile(localURL: localURL, remotePath: remotePath)
    }

    func createRemoteFolder(name: String) async {
        let path = currentPath.hasSuffix("/") ? currentPath + name : currentPath + "/" + name
        do {
            try await ftpService.createDirectory(remotePath: path)
            await loadDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRemoteItem(_ item: RemoteFileItem) async {
        do {
            if item.isDirectory {
                try await ftpService.deleteDirectory(remotePath: item.path)
            } else {
                try await ftpService.deleteFile(remotePath: item.path)
            }
            await loadDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameRemoteItem(_ item: RemoteFileItem, to newName: String) async {
        let newPath = (item.path as NSString).deletingLastPathComponent + "/" + newName
        do {
            try await ftpService.rename(from: item.path, to: newPath)
            await loadDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        ftpService.disconnect()
        isConnected = false
        files = []
    }
}
