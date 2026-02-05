//
//  ConnectionControlsView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

struct ConnectionControlsView: View {
    @ObservedObject var connection: BLEConnection
    @ObservedObject var logger: Logger
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                Button(action: {
                    if connection.isScanning {
                        connection.stopScanning()
                    } else {
                        connection.startScanning()
                    }
                }) {
                    Text(connection.isScanning ? "Stop Scan" : "Connect")
                        .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(connection.isConnected)
                
                Button(action: {
                    connection.disconnect()
                }) {
                    Text("Disconnect")
                        .frame(width: 120)
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConnected)
            }
        }
    }
}
