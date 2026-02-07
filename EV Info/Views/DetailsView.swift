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
        VStack(spacing: 0) {
            // Header controls
            VStack(spacing: 10) {
                HStack {
                    Text("Debug Log")
                        .font(.headline)
                    Spacer()
                    
                    Picker("Log Level", selection: $logger.logLevel) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                }
                
                Button("Check Status") {
                    connection.checkBluetoothStatus()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Full-screen scrollable log
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.messages.reversed(), id: \.id) { message in
                        Text(message.formattedMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
