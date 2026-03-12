import SwiftUI

struct RemoteBrowserView: View {
    let serverId: String
    @StateObject private var viewModel: RemoteBrowserViewModel
    @EnvironmentObject var appState: AppState
    
    init(serverId: String) {
        self.serverId = serverId
        _viewModel = StateObject(wrappedValue: RemoteBrowserViewModel(serverId: serverId))
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Image(systemName: "folder")
                    Text(viewModel.currentPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !viewModel.pathHistory.isEmpty {
                        Button {
                            Task { await viewModel.navigateUp() }
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                    }
                }
                .padding(.vertical, 4)
                
                ForEach(viewModel.files) { item in
                    Button {
                        if item.isDirectory {
                            Task { await viewModel.navigateInto(item) }
                        } else {
                            // Download and sync options
                            showItemOptions(item)
                        }
                    } label: {
                        HStack {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                                .foregroundColor(item.isDirectory ? .osamAccent : .secondary)
                            Text(item.name)
                            Spacer()
                            if !item.isDirectory {
                                Text(formatSize(item.size))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Remote Files")
        .onAppear {
            if let server = appState.servers.first(where: { $0.id == serverId }) {
                Task { await viewModel.connect(credential: server) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Sync this folder
                    if appState.servers.contains(where: { $0.id == serverId }) {
                        // For simplicity, we assume we want to sync with a local project
                        // We'd normally have a way to pick the local root
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
    }
    
    private func showItemOptions(_ item: RemoteFileItem) {
        // Implementation for downloading/viewing remote file
    }
    
    private func formatSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
