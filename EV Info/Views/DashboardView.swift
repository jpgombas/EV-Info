//
//  DashboardView.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var connection: BLEConnection
    @ObservedObject var controller: OBD2Controller
    @ObservedObject var logger: Logger
    @ObservedObject var syncManager: SyncManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection and Sync Status Row
            HStack(spacing: 12) {
                ConnectionStatusView(
                    connectionStatus: connection.connectionStatus,
                    isConnected: connection.isConnected
                )
                
                SyncStatusView(syncManager: syncManager)
            }
            
            VehicleDataView(vehicleData: controller.vehicleData)
            
            ConnectionControlsView(
                connection: connection,
                logger: logger
            )
            
            Spacer()
        }
        .padding()
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Prevent screen from sleeping while on dashboard
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable screen sleep when leaving dashboard
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @ObservedObject var syncManager: SyncManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: syncManager.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                    .foregroundColor(syncManager.isSyncing ? .blue : .green)
                    .font(.caption)
                Text("Sync")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                // Pending count
                Label {
                    Text("\(syncManager.pendingRecordCount)")
                        .font(.caption2)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                
                // Synced count
                Label {
                    Text("\(syncManager.totalSyncedRecords)")
                        .font(.caption2)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}
