import Foundation

struct EditorTab: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let language: Language
    var isModified: Bool = false
    var isRemote: Bool = false
    var remotePath: String?
    var serverId: String?

    init(url: URL, isRemote: Bool = false, remotePath: String? = nil, serverId: String? = nil) {
        self.id = isRemote ? (remotePath ?? url.absoluteString) : url.absoluteString
        self.url = url
        self.name = url.lastPathComponent
        self.language = Language.detect(from: url.pathExtension)
        self.isRemote = isRemote
        self.remotePath = remotePath
        self.serverId = serverId
    }
}
