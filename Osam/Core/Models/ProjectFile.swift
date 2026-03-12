import Foundation
import UniformTypeIdentifiers

struct ProjectFile: Identifiable, Hashable, Comparable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date
    var children: [ProjectFile]?

    var language: Language {
        Language.detect(from: url.pathExtension)
    }

    var icon: String {
        if isDirectory { return "folder.fill" }
        switch language {
        case .php: return "chevron.left.forwardslash.chevron.right"
        case .html: return "doc.richtext"
        case .css: return "paintbrush"
        case .javascript: return "bolt"
        case .json: return "curlybraces"
        case .markdown: return "doc.text"
        case .plainText: return "doc"
        }
    }

    static func < (lhs: ProjectFile, rhs: ProjectFile) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    init(url: URL) {
        self.id = url.absoluteString
        self.url = url
        self.name = url.lastPathComponent

        let resources = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey
        ])
        self.isDirectory = resources?.isDirectory ?? false
        self.size = Int64(resources?.fileSize ?? 0)
        self.modifiedDate = resources?.contentModificationDate ?? Date.distantPast
        self.children = nil
    }

    init(name: String, isDirectory: Bool, size: Int64, modifiedDate: Date, remotePath: String) {
        self.id = remotePath
        self.url = URL(string: remotePath) ?? URL(fileURLWithPath: remotePath)
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
        self.children = nil
    }
}
