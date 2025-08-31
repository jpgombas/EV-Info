//
//  ContentView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var logger = Logger()
    @StateObject private var connection: BLEConnection
    @StateObject private var controller: OBD2Controller
    
    init() {
        let logger = Logger()
        let connection = BLEConnection(logger: logger)
        let parser = OBD2Parser(logger: logger)
        let controller = OBD2Controller(connection: connection, parser: parser, logger: logger)
        
        self._logger = StateObject(wrappedValue: logger)
        self._connection = StateObject(wrappedValue: connection)
        self._controller = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ConnectionStatusView(connectionStatus: connection.connectionStatus, isConnected: connection.isConnected)
                
                VehicleDataView(vehicleData: controller.vehicleData)
                
                ConnectionControlsView(
                    connection: connection,
                    logger: logger
                )
                
                Spacer()
                
                DebugLogView(logger: logger)
            }
            .padding()
        }
    }
}
