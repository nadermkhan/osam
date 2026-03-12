import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Editor") {
                Toggle("Dark Mode", isOn: $appState.settings.darkMode)
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    Stepper("\(Int(appState.settings.fontSize))pt", value: $appState.settings.fontSize, in: 10...24)
                }
                
                Picker("Font", selection: $appState.settings.fontName) {
                    Text("Menlo").tag("Menlo")
                    Text("Courier").tag("Courier")
                    Text("SF Mono").tag("SFMono-Regular")
                }
                
                HStack {
                    Text("Tab Width")
                    Spacer()
                    Stepper("\(appState.settings.tabWidth)", value: $appState.settings.tabWidth, in: 2...8)
                }
                
                Toggle("Use Spaces for Tabs", isOn: $appState.settings.useSpacesForTabs)
                Toggle("Show Line Numbers", isOn: $appState.settings.showLineNumbers)
            }
            
            Section("File Operations") {
                Toggle("Auto Save", isOn: $appState.settings.autoSave)
                Toggle("Confirm Sync Deletions", isOn: $appState.settings.syncDeleteConfirm)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: appState.settings.darkMode) { _ in appState.saveSettings() }
        .onDisappear { appState.saveSettings() }
    }
}
