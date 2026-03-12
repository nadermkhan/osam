import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings

    private let persistence = PersistenceManager.shared

    init() {
        self.settings = PersistenceManager.shared.loadSettings()
    }

    func save() {
        persistence.saveSettings(settings)
    }
}
