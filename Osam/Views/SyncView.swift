import SwiftUI

struct SyncView: View {
    let config: SyncConfiguration
    @StateObject private var viewModel: SyncViewModel
    @EnvironmentObject var appState: AppState
    
    init(config: SyncConfiguration) {
        self.config = config
        _viewModel = StateObject(wrappedValue: SyncViewModel(config: config))
    }
    
    var body: some View {
        VStack {
            if viewModel.isPlanning {
                planningView
            } else if viewModel.isSyncing {
                syncingView
            } else if let plan = viewModel.plan {
                planSummaryView(plan)
            } else {
                initialView
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.osamAccent)
            Text("Ready to Sync")
                .font(.headline)
            Text("Comparing \(config.localRoot.lastPathComponent) with remote server...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                if let server = appState.servers.first(where: { $0.id == config.serverId }) {
                    Task { await viewModel.planSync(credential: server) }
                }
            } label: {
                Text("Analyze Sync")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.osamAccent)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
    
    private var planningView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Analyzing differences...")
            Text("Comparing local and remote file states.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var syncingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progress.fraction)
                .padding()
            Text(viewModel.progress.phase.rawValue)
            Text(viewModel.progress.currentFile)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal)
            
            Button("Cancel") {
                Task { await viewModel.cancelSync() }
            }
            .foregroundColor(.osamRed)
        }
    }
    
    private func planSummaryView(_ plan: SyncPlan) -> some View {
        VStack(spacing: 0) {
            List {
                Section("Summary") {
                    HStack {
                        Label("Uploads", systemImage: "arrow.up.circle")
                        Spacer()
                        Text("\(plan.uploads.count)")
                    }
                    HStack {
                        Label("Downloads", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(plan.downloads.count)")
                    }
                    HStack {
                        Label("Conflicts", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Text("\(plan.conflicts.count)")
                            .foregroundColor(plan.conflicts.isEmpty ? .secondary : .osamRed)
                    }
                }
                
                if !plan.conflicts.isEmpty {
                    Section("Conflicts") {
                        ForEach(plan.conflicts.indices, id: \.self) { idx in
                            ConflictRow(conflict: plan.conflicts[idx]) { resolution in
                                viewModel.resolveConflict(at: idx, with: resolution)
                            }
                        }
                    }
                }
            }
            
            VStack {
                Button {
                    Task { await viewModel.applySync() }
                } label: {
                    Text("Apply Changes")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.osamGreen)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!plan.conflicts.allSatisfy { $0.resolution != .skip })
            }
            .padding()
            .background(Color.osamSurface)
        }
    }
}

struct ConflictRow: View {
    let conflict: SyncConflict
    let onResolve: (SyncConflict.ConflictResolution) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(conflict.relativePath)
                .font(.subheadline)
                .lineLimit(1)
            
            Picker("Resolution", selection: Binding(
                get: { conflict.resolution },
                set: { onResolve($0) }
            )) {
                Text("Skip").tag(SyncConflict.ConflictResolution.skip)
                Text("Local").tag(SyncConflict.ConflictResolution.keepLocal)
                Text("Remote").tag(SyncConflict.ConflictResolution.keepRemote)
                Text("Both").tag(SyncConflict.ConflictResolution.duplicate)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}
