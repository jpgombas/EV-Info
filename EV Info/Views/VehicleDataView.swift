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
        VStack(spacing: 17) {
            HStack(spacing: 26) {
                DataCard(title: "Vehicle Speed", value: "\(Int(vehicleData.speed))", unit: "mph")
                DataCard(title: "Power", value: String(format: "%.1f", vehicleData.power), unit: "kW")
            }

            HStack(spacing: 26) {
                DataCard(title: "Battery Current", value: String(format: "%.1f", vehicleData.batteryCurrent), unit: "A")
                DataCard(title: "Voltage", value: String(format: "%.1f", vehicleData.voltage), unit: "V")
            }

            HStack(spacing: 26) {
                DataCard(title: "Battery Level", value: String(format: "%.1f", vehicleData.stateOfCharge), unit: "%")
                DataCard(title: "Efficiency", value: String(format: "%.1f", vehicleData.efficiency), unit: "mi/kWh")
            }

            HStack(spacing: 26) {
                DataCard(title: "HVAC Power", value: "\(Int(vehicleData.hvacMeasuredPowerW))", unit: "W")
                DataCard(title: "Battery Temp", value: String(format: "%.0f", vehicleData.batteryAvgTempC), unit: "°C")
            }

            HStack(spacing: 26) {
                DataCard(title: "Distance", value: String(format: "%.1f", vehicleData.relativeDistance), unit: "mi")
                DataCard(title: "Ambient Temp", value: String(format: "%.1f", vehicleData.ambientTempF), unit: "°F")
            }
        }
    }
}

struct DataCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(13)
    }
}
