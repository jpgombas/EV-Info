//
//  PowerCard.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct PowerCard: View {
    let vehicleData: VehicleData
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Power\nAnalysis")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 10) {
                PowerMetric(
                    title: "Power",
                    value: String(format: "%.2f", vehicleData.power),
                    unit: "kW",
                    color: powerColor
                )
                
                PowerMetric(
                    title: "Voltage",
                    value: String(format: "%.1f", vehicleData.voltage),
                    unit: "V",
                    color: .blue
                )
                
                PowerMetric(
                    title: "Current",
                    value: String(format: "%.1f", vehicleData.batteryCurrent),
                    unit: "A",
                    color: currentColor
                )
                
                PowerMetric(
                    title: "Efficiency",
                    value: vehicleData.efficiency > 0 ? String(format: "%.2f", vehicleData.efficiency) : "--",
                    unit: "mi/kWh",
                    color: .green
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var powerColor: Color {
        if vehicleData.power > 20 { return .red }
        else if vehicleData.power > 10 { return .orange }
        else { return .green }
    }
    
    private var currentColor: Color {
        if vehicleData.batteryCurrent > 0 { return .red }  // Discharging
        else if vehicleData.batteryCurrent < -5 { return .green }  // Charging
        else { return .blue }  // Near zero
    }
}

struct PowerMetric: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(alignment: .bottom, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 1)
            }
        }
    }
}
