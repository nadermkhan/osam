import SwiftUI

struct ProjectBrowserView: View {
    let rootURL: URL
    @StateObject private var viewModel: ProjectViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorViewModel: EditorViewModel // Assuming we might need this or use AppRoute

    init(rootURL: URL) {
        self.rootURL = rootURL
        _viewModel = StateObject(wrappedValue: ProjectViewModel(rootURL: rootURL))
    }

    var body: some View {
        List {
            ForEach(viewModel.files) { file in
                FileRow(file: file, viewModel: viewModel)
            }
        }
        .navigationTitle(rootURL.lastPathComponent)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // Create file logic
                    } label: {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    Button {
                        // Create folder logic
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct FileRow: View {
    let file: ProjectFile
    @ObservedObject var viewModel: ProjectViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if file.isDirectory {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { viewModel.expandedFolders.contains(file.id) },
                        set: { _ in viewModel.toggleFolder(file) }
                    ),
                    content: {
                        if let children = viewModel.loadChildren(for: file) {
                            ForEach(children) { child in
                                FileRow(file: child, viewModel: viewModel)
                            }
                        }
                    },
                    label: {
                        Label(file.name, systemImage: "folder.fill")
                            .foregroundColor(.osamAccent)
                    }
                )
            } else {
                Button {
                    // Open file
                    NotificationCenter.default.post(name: .openLocalFile, object: file.url)
                    appState.navigationPath.append(AppRoute.editor)
                } label: {
                    Label(file.name, systemImage: file.icon)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

extension Notification.Name {
    static let openLocalFile = Notification.Name("openLocalFile")
}
