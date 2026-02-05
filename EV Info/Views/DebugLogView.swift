//
//  DebugLogView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

struct DebugLogView: View {
    @ObservedObject var logger: Logger
    @ObservedObject var connection: BLEConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
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
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.messages.reversed(), id: \.id) { message in
                        Text(message.formattedMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        
        Button("Check Status") {
            connection.checkBluetoothStatus()
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }
}
