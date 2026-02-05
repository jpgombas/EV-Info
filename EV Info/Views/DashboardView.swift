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
    
    var body: some View {
        VStack(spacing: 20) {
            ConnectionStatusView(
                connectionStatus: connection.connectionStatus,
                isConnected: connection.isConnected
            )
            
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
    }
}
