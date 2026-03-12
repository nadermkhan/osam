import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFilePicker = false

    var body: some View {
        List {
            Section("Recent Projects") {
                if appState.recentProjects.isEmpty {
                    Text("No recent projects")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(appState.recentProjects, id: \.self) { url in
                        Button {
                            appState.navigationPath.append(AppRoute.projectBrowser(url))
                            appState.addRecentProject(url)
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.osamAccent)
                                Text(url.lastPathComponent)
                                Spacer()
                                Text(url.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Section("Servers") {
                ForEach(appState.servers) { server in
                    Button {
                        appState.navigationPath.append(AppRoute.remoteBrowser(server.id))
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.osamAccent)
                            VStack(alignment: .leading) {
                                Text(server.label)
                                Text(server.host)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                appState.navigationPath.append(AppRoute.serverForm(server))
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                }

                Button {
                    appState.navigationPath.append(AppRoute.serverForm(nil))
                } label: {
                    Label("Add Server", systemImage: "plus")
                        .foregroundColor(.osamAccent)
                }
            }
        }
        .navigationTitle("Osam")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appState.navigationPath.append(AppRoute.settings)
                } label: {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Open Project", systemImage: "folder.badge.plus")
                        .font(.headline)
                }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            ProjectPicker { url in
                appState.addRecentProject(url)
                appState.navigationPath.append(AppRoute.projectBrowser(url))
            }
        }
    }
}

struct ProjectPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: ProjectPicker

        init(_ parent: ProjectPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
