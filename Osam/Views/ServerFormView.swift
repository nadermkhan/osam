import SwiftUI

struct ServerFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var label = ""
    @State private var host = ""
    @State private var port = "21"
    @State private var username = ""
    @State private var password = ""
    @State private var useFTPS = false
    @State private var initialPath = "/"
    
    let existing: ServerCredential?
    
    var body: some View {
        Form {
            Section("Connection") {
                TextField("Label (e.g. My Website)", text: $label)
                TextField("Host (e.g. ftp.example.com)", text: $host)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
            }
            
            Section("Authentication") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
            }
            
            Section("Options") {
                Toggle("Use FTPS (TLS)", isOn: $useFTPS)
                TextField("Initial Path", text: $initialPath)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            if existing != nil {
                Section {
                    Button("Delete Server", role: .destructive) {
                        if let existing = existing {
                            appState.deleteServer(existing)
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? "New Server" : "Edit Server")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                }
                .disabled(label.isEmpty || host.isEmpty)
            }
        }
        .onAppear {
            if let existing = existing {
                label = existing.label
                host = existing.host
                port = "\(existing.port)"
                username = existing.username
                useFTPS = existing.useFTPS
                initialPath = existing.initialPath
                password = KeychainManager.shared.load(key: existing.keychainKey) ?? ""
            }
        }
    }
    
    private func save() {
        var server = existing ?? ServerCredential()
        server.label = label
        server.host = host
        server.port = Int(port) ?? 21
        server.username = username
        server.useFTPS = useFTPS
        server.initialPath = initialPath
        
        appState.saveServer(server, password: password)
        dismiss()
    }
}
