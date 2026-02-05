import Foundation

/// Enhanced data point structure for Databricks storage
/// Compatible with both existing VehicleData and cloud synchronization
struct VehicleDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    
    // Vehicle telemetry
    var soc: Double? // State of charge (%)
    var batteryCapacityKWh: Double?
    var batteryTempCelsius: Double?
    var batteryTempFahrenheit: Double?
    var isCharging: Bool?
    var speedKmh: Int?
    var currentAmps: Double?
    var voltageVolts: Double?
    var cabinACPowerWatts: Double?
    var cabinHeatPowerWatts: Double?
    var transmissionPosition: Int?
    
    // Tracking
    var syncedToDatabricks: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case soc
        case batteryCapacityKWh
        case batteryTempCelsius
        case batteryTempFahrenheit
        case isCharging
        case speedKmh
        case currentAmps
        case voltageVolts
        case cabinACPowerWatts
        case cabinHeatPowerWatts
        case transmissionPosition
        case syncedToDatabricks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.soc = try container.decodeIfPresent(Double.self, forKey: .soc)
        self.batteryCapacityKWh = try container.decodeIfPresent(Double.self, forKey: .batteryCapacityKWh)
        self.batteryTempCelsius = try container.decodeIfPresent(Double.self, forKey: .batteryTempCelsius)
        self.batteryTempFahrenheit = try container.decodeIfPresent(Double.self, forKey: .batteryTempFahrenheit)
        self.isCharging = try container.decodeIfPresent(Bool.self, forKey: .isCharging)
        self.speedKmh = try container.decodeIfPresent(Int.self, forKey: .speedKmh)
        self.currentAmps = try container.decodeIfPresent(Double.self, forKey: .currentAmps)
        self.voltageVolts = try container.decodeIfPresent(Double.self, forKey: .voltageVolts)
        self.cabinACPowerWatts = try container.decodeIfPresent(Double.self, forKey: .cabinACPowerWatts)
        self.cabinHeatPowerWatts = try container.decodeIfPresent(Double.self, forKey: .cabinHeatPowerWatts)
        self.transmissionPosition = try container.decodeIfPresent(Int.self, forKey: .transmissionPosition)
        self.syncedToDatabricks = try container.decodeIfPresent(Bool.self, forKey: .syncedToDatabricks) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(soc, forKey: .soc)
        try container.encodeIfPresent(batteryCapacityKWh, forKey: .batteryCapacityKWh)
        try container.encodeIfPresent(batteryTempCelsius, forKey: .batteryTempCelsius)
        try container.encodeIfPresent(batteryTempFahrenheit, forKey: .batteryTempFahrenheit)
        try container.encodeIfPresent(isCharging, forKey: .isCharging)
        try container.encodeIfPresent(speedKmh, forKey: .speedKmh)
        try container.encodeIfPresent(currentAmps, forKey: .currentAmps)
        try container.encodeIfPresent(voltageVolts, forKey: .voltageVolts)
        try container.encodeIfPresent(cabinACPowerWatts, forKey: .cabinACPowerWatts)
        try container.encodeIfPresent(cabinHeatPowerWatts, forKey: .cabinHeatPowerWatts)
        try container.encodeIfPresent(transmissionPosition, forKey: .transmissionPosition)
        try container.encode(syncedToDatabricks, forKey: .syncedToDatabricks)
    }
    
    /// Initialize from existing VehicleData struct
    init(from vehicleData: VehicleData) {
        self.id = UUID()
        self.timestamp = Date()
        self.speedKmh = Int(vehicleData.speed)
        self.currentAmps = vehicleData.batteryCurrent
        self.voltageVolts = vehicleData.voltage
    }
    
    /// Initialize with timestamp
    init(timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
    }
    
    init(id: UUID, timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }
    
    /// Format for CSV export
    func toCSVRow() -> String {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: self.timestamp)
        let soc = self.soc?.description ?? ""
        let capacity = batteryCapacityKWh?.description ?? ""
        let tempC = batteryTempCelsius?.description ?? ""
        let tempF = batteryTempFahrenheit?.description ?? ""
        let charging = isCharging?.description ?? ""
        let speed = speedKmh?.description ?? ""
        let current = currentAmps?.description ?? ""
        let voltage = voltageVolts?.description ?? ""
        let acPower = cabinACPowerWatts?.description ?? ""
        let heatPower = cabinHeatPowerWatts?.description ?? ""
        let transmission = transmissionPosition?.description ?? ""
        
        return [timestamp, soc, capacity, tempC, tempF, charging, speed, current, voltage, acPower, heatPower, transmission].joined(separator: ",")
    }
    
    static var csvHeader: String {
        return "timestamp,soc,battery_capacity_kwh,battery_temp_celsius,battery_temp_fahrenheit,is_charging,speed_kmh,current_amps,voltage_volts,cabin_ac_power_watts,cabin_heat_power_watts,transmission_position"
    }
}
