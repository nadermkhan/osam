import SwiftUI

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var plan: SyncPlan?
    @Published var progress = SyncProgress()
    @Published var isPlanning = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var conflicts: [SyncConflict] = []

    let config: SyncConfiguration
    let syncEngine = SyncEngine()
    var ftpService: FTPService?

    init(config: SyncConfiguration) {
        self.config = config
    }

    func planSync(credential: ServerCredential) async {
        isPlanning = true
        errorMessage = nil
        do {
            let ftp = FTPService()
            let password = KeychainManager.shared.load(key: credential.keychainKey) ?? ""
            try await ftp.connect(credential: credential, password: password)
            self.ftpService = ftp

            let plan = try await syncEngine.planSync(config: config, ftpService: ftp)
            self.plan = plan
            self.conflicts = plan.conflicts
        } catch {
            errorMessage = error.localizedDescription
        }
        isPlanning = false
    }

    func resolveConflict(at index: Int, with resolution: SyncConflict.ConflictResolution) {
        guard index < conflicts.count else { return }
        conflicts[index].resolution = resolution
        plan?.conflicts = conflicts
    }

    func applySync() async {
        guard let plan = plan, let ftp = ftpService else { return }
        isSyncing = true
        errorMessage = nil
        do {
            try await syncEngine.applySync(plan: plan, config: config, ftpService: ftp)
            let engineProgress = await syncEngine.progress
            progress = engineProgress
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }

    func cancelSync() async {
        await syncEngine.cancel()
    }

    func refreshProgress() async {
        progress = await syncEngine.progress
    }
}
