import SwiftUI

struct EditorContainerView: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject var appState: AppState

    /// When presented from a project, the root URL is passed to show the file tree sidebar.
    var projectRootURL: URL?

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 700
            if isWide, let rootURL = projectRootURL {
                // iPad / wide layout: sidebar + editor
                HStack(spacing: 0) {
                    SidebarFileTree(rootURL: rootURL, viewModel: viewModel)
                        .frame(width: 260)
                    Divider()
                    editorContent
                }
            } else {
                editorContent
            }
        }
        .navigationTitle(viewModel.activeTab?.name ?? "Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let rootURL = projectRootURL {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(value: AppRoute.projectBrowser(rootURL)) {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLocalFile)) { notification in
            if let url = notification.object as? URL {
                viewModel.openFile(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorInsertCharacter)) { notification in
            if let char = notification.object as? String {
                viewModel.content.append(char)
            }
        }
        .environmentObject(viewModel)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            if viewModel.tabs.isEmpty {
                emptyState
            } else {
                TabBarView(viewModel: viewModel)

                ZStack(alignment: .bottom) {
                    if let activeTab = viewModel.activeTab {
                        CodeEditorView(
                            text: $viewModel.content,
                            language: activeTab.language,
                            settings: appState.settings,
                            onTextChange: { content in
                                viewModel.contentDidChange(content)
                            }
                        )
                    }

                    if viewModel.showAutocomplete {
                        AutocompleteOverlay(viewModel: viewModel)
                    }
                }

                EditorToolbar(
                    onTab: { viewModel.content.append("    ") },
                    onUndo: { viewModel.undo() },
                    onRedo: { viewModel.redo() },
                    onFind: { viewModel.showFindBar.toggle() },
                    onSave: { viewModel.saveCurrentFile() }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Open Files")
                .font(.headline)
            Text("Select a file from the browser to start editing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.osamBackground)
    }
}

/// Inline sidebar file tree used in wide layouts (iPad).
struct SidebarFileTree: View {
    let rootURL: URL
    @ObservedObject var viewModel: EditorViewModel
    @StateObject private var projectVM: ProjectViewModel

    init(rootURL: URL, viewModel: EditorViewModel) {
        self.rootURL = rootURL
        self.viewModel = viewModel
        _projectVM = StateObject(wrappedValue: ProjectViewModel(rootURL: rootURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rootURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.osamSurface)

            List {
                ForEach(projectVM.files) { file in
                    SidebarFileRow(file: file, projectVM: projectVM, editorVM: viewModel)
                }
            }
            .listStyle(.plain)
        }
        .background(Color.osamSurface)
    }
}

struct SidebarFileRow: View {
    let file: ProjectFile
    @ObservedObject var projectVM: ProjectViewModel
    @ObservedObject var editorVM: EditorViewModel

    var body: some View {
        Group {
            if file.isDirectory {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { projectVM.expandedFolders.contains(file.id) },
                        set: { _ in projectVM.toggleFolder(file) }
                    ),
                    content: {
                        let children = projectVM.loadChildren(for: file)
                        ForEach(children) { child in
                            SidebarFileRow(file: child, projectVM: projectVM, editorVM: editorVM)
                        }
                    },
                    label: {
                        Label(file.name, systemImage: "folder.fill")
                            .foregroundColor(.osamAccent)
                            .font(.caption)
                    }
                )
            } else {
                Button {
                    editorVM.openFile(url: file.url)
                } label: {
                    Label(file.name, systemImage: file.icon)
                        .foregroundColor(.primary)
                        .font(.caption)
                }
            }
        }
    }
}

struct AutocompleteOverlay: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack {
            Spacer()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.autocompleSuggestions) { suggestion in
                        Button {
                            viewModel.content.append(suggestion.insertText)
                            viewModel.showAutocomplete = false
                        } label: {
                            HStack {
                                Image(systemName: suggestionIcon(suggestion.type))
                                    .foregroundColor(suggestionColor(suggestion.type))
                                Text(suggestion.text)
                                Spacer()
                                Text(suggestion.detail)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                        Divider()
                    }
                }
            }
            .background(Color.osamSurface)
            .cornerRadius(8)
            .shadow(radius: 10)
            .frame(maxHeight: 200)
            .padding()
        }
    }

    func suggestionIcon(_ type: AutocompleteEngine.Suggestion.SuggestionType) -> String {
        switch type {
        case .keyword: return "key"
        case .snippet: return "text.badge.plus"
        case .word: return "abc"
        }
    }

    func suggestionColor(_ type: AutocompleteEngine.Suggestion.SuggestionType) -> Color {
        switch type {
        case .keyword: return .osamAccent
        case .snippet: return .osamGreen
        case .word: return .secondary
        }
    }
}
