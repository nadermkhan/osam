import SwiftUI

struct ProjectBrowserView: View {
    let rootURL: URL
    @StateObject private var viewModel: ProjectViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var editorViewModel: EditorViewModel

    @State private var showNewFileAlert = false
    @State private var showNewFolderAlert = false
    @State private var newItemName = ""

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
                        newItemName = ""
                        showNewFileAlert = true
                    } label: {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    Button {
                        newItemName = ""
                        showNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New File", isPresented: $showNewFileAlert) {
            TextField("filename.swift", text: $newItemName)
            Button("Create") {
                let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                viewModel.createFile(name: name, in: rootURL)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new file.")
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("FolderName", text: $newItemName)
            Button("Create") {
                let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                viewModel.createFolder(name: name, in: rootURL)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new folder.")
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
                        let children = viewModel.loadChildren(for: file)
                        ForEach(children) { child in
                            FileRow(file: child, viewModel: viewModel)
                        }
                    },
                    label: {
                        Label(file.name, systemImage: "folder.fill")
                            .foregroundColor(.osamAccent)
                    }
                )
            } else {
                Button {
                    NotificationCenter.default.post(name: .openLocalFile, object: file.url)
                    appState.navigationPath.append(AppRoute.editor(viewModel.rootURL))
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
