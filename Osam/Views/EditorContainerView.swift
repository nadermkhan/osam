import SwiftUI

struct EditorContainerView: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
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
        .navigationTitle(viewModel.activeTab?.name ?? "Editor")
        .navigationBarTitleDisplayMode(.inline)
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

struct AutocompleteOverlay: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack {
            Spacer()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.autocompleSuggestions) { suggestion in
                        Button {
                            // Find prefix and replace
                            // This logic is simplified for now
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
