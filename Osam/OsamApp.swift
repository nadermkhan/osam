import SwiftUI

@main
struct OsamApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.settings.darkMode ? .dark : .light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .projectBrowser(let url):
                        ProjectBrowserView(rootURL: url)
                    case .editor(let projectURL):
                        EditorContainerView(projectRootURL: projectURL)
                    case .remoteBrowser(let serverId):
                        RemoteBrowserView(serverId: serverId)
                    case .sync(let config):
                        SyncView(config: config)
                    case .settings:
                        SettingsView()
                    case .serverForm(let server):
                        ServerFormView(existing: server)
                    }
                }
        }
    }
}

enum AppRoute: Hashable {
    case projectBrowser(URL)
    case editor(URL?)
    case remoteBrowser(String)
    case sync(SyncConfiguration)
    case settings
    case serverForm(ServerCredential?)
}
