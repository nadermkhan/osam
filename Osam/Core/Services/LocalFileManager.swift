import Foundation

final class LocalFileManager {
    static let shared = LocalFileManager()
    private let fm = FileManager.default

    func listContents(of url: URL) throws -> [ProjectFile] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        return contents.map { ProjectFile(url: $0) }.sorted()
    }

    func readFile(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func writeFile(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func createFile(at url: URL, content: String = "") throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func createFolder(at url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func rename(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fm.moveItem(at: url, to: newURL)
        return newURL
    }

    func delete(at url: URL) throws {
        try fm.removeItem(at: url)
    }

    func exists(at url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }

    func recursiveList(of url: URL, relativeTo base: URL) throws -> [FileMetadata] {
        var results: [FileMetadata] = []
        let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            let resources = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            guard !(resources.isDirectory ?? false) else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: base.path + "/", with: "")
            results.append(FileMetadata(
                relativePath: relativePath,
                size: Int64(resources.fileSize ?? 0),
                modified: resources.contentModificationDate ?? Date.distantPast,
                isDirectory: false
            ))
        }
        return results
    }

    func searchFiles(in url: URL, query: String) throws -> [URL] {
        var results: [URL] = []
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let lowerQuery = query.lowercased()
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased().contains(lowerQuery) {
                results.append(fileURL)
            }
            if results.count >= 100 { break }
        }
        return results
    }

    func searchInFiles(in url: URL, query: String) throws -> [(URL, Int, String)] {
        var results: [(URL, Int, String)] = []
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        while let fileURL = enumerator?.nextObject() as? URL {
            let resources = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            guard !(resources?.isDirectory ?? true) else { continue }
            let lang = Language.detect(from: fileURL.pathExtension)
            guard lang != .plainText || fileURL.pathExtension == "txt" else { continue }
            let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                if line.localizedCaseInsensitiveContains(query) {
                    results.append((fileURL, i + 1, line.trimmingCharacters(in: .whitespaces)))
                    if results.count >= 200 { return results }
                }
            }
        }
        return results
    }
}

struct FileMetadata {
    let relativePath: String
    let size: Int64
    let modified: Date
    let isDirectory: Bool
}
