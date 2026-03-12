import SwiftUI

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var rootURL: URL
    @Published var files: [ProjectFile] = []
    @Published var expandedFolders: Set<String> = []
    @Published var searchQuery = ""
    @Published var searchResults: [URL] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let fileManager = LocalFileManager.shared

    init(rootURL: URL) {
        self.rootURL = rootURL
        loadFiles()
    }

    func loadFiles() {
        isLoading = true
        do {
            files = try fileManager.listContents(of: rootURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadChildren(for file: ProjectFile) -> [ProjectFile] {
        guard file.isDirectory else { return [] }
        return (try? fileManager.listContents(of: file.url)) ?? []
    }

    func toggleFolder(_ file: ProjectFile) {
        if expandedFolders.contains(file.id) {
            expandedFolders.remove(file.id)
        } else {
            expandedFolders.insert(file.id)
        }
    }

    func createFile(name: String, in directory: URL) {
        do {
            let url = directory.appendingPathComponent(name)
            try fileManager.createFile(at: url)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFolder(name: String, in directory: URL) {
        do {
            let url = directory.appendingPathComponent(name)
            try fileManager.createFolder(at: url)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(file: ProjectFile, to newName: String) {
        do {
            _ = try fileManager.rename(at: file.url, to: newName)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(file: ProjectFile) {
        do {
            try fileManager.delete(at: file.url)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        searchResults = (try? fileManager.searchFiles(in: rootURL, query: searchQuery)) ?? []
    }
}
