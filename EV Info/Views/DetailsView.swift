//
//  DetailsView.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct DetailsView: View {
    @ObservedObject var controller: OBD2Controller
    @ObservedObject var logger: Logger
    @ObservedObject var connection: BLEConnection

    var body: some View {
        VStack(spacing: 20) {
            // Power and Distance Cards
            HStack(spacing: 20) {
                PowerCard(vehicleData: controller.vehicleData)
                DistanceCard(
                    vehicleData: controller.vehicleData,
                    onReset: { controller.resetDistance() }
                )
            }
            
            Spacer()
            
            // Debug Log takes up remaining space
            DebugLogView(logger: logger, connection: connection)
        }
        .padding()
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
