//
//  VehicleDataView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

struct VehicleDataView: View {
    let vehicleData: VehicleData
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                DataCard(title: "Vehicle Speed", value: "\(Int(vehicleData.speed))", unit: "mph")
                DataCard(title: "Battery Current", value: String(format: "%.1f", vehicleData.batteryCurrent), unit: "A")
            }
            
            HStack(spacing: 30) {
                DataCard(title: "Voltage", value: String(format: "%.1f", vehicleData.voltage), unit: "V")
                DataCard(title: "Power", value: String(format: "%.1f", vehicleData.power), unit: "kW")
            }
            
            HStack(spacing: 30) {
                DataCard(title: "Battery Level", value: String(format: "%.1f", vehicleData.stateOfCharge), unit: "%")
                DataCard(title: "Efficiency", value: String(format: "%.1f", vehicleData.efficiency), unit: "mi/kWh")
            }
            HStack(spacing: 30) {
                DataCard(title: "Distance", value: String(format: "%.1f", vehicleData.relativeDistance), unit: "mi")
                DataCard(title: "Temperature", value: String(format: "%.1f", vehicleData.ambientTempF), unit: "F")
            }
        }
    }
}

struct DataCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(alignment: .bottom, spacing: 5) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                Text(unit)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}
