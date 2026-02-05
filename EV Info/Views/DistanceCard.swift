//
//  DistanceCard.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct DistanceCard: View {
    let vehicleData: VehicleData
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Trip Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                // Distance
                VStack {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 5) {
                        Text(String(format: "%.2f", vehicleData.distance))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                        Text("mi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                }
                
                Divider()
                
                // Current Speed
                VStack {
                    Text("Current Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 5) {
                        Text(String(format: "%.0f", vehicleData.speed))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("mph")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                }
                
                Divider()
                
                // Energy used (estimate)
                VStack {
                    Text("Est. Energy Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 5) {
                        let energyUsed = vehicleData.distance * (vehicleData.efficiency > 0 ? (1.0 / vehicleData.efficiency) : 0)
                        Text(String(format: "%.2f", energyUsed))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("kWh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 1)
                    }
                }
            }
            
            Button(action: onReset) {
                Text("Reset Trip")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}
