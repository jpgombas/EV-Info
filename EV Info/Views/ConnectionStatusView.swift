//
//  ConnectionStatusView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

struct ConnectionStatusView: View {
    let connectionStatus: String
    let isConnected: Bool
    
    var body: some View {
        Text(connectionStatus)
            .foregroundColor(isConnected ? .green : .red)
            .font(.subheadline)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
    }
}
