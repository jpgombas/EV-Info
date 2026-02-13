import Foundation

/// Enhanced data point structure for Databricks storage
/// Compatible with both existing VehicleData and cloud synchronization
struct VehicleDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date

    // Vehicle telemetry
    var soc: Double? // State of charge displayed (%)
    var speedKmh: Int?
    var currentAmps: Double?
    var voltageVolts: Double?
    var distanceMi: Double?
    var ambientTempF: Double?

    // Efficiency-related fields
    var socHD: Double?                // Raw high-resolution SOC (%)
    var batteryAvgTempC: Double?
    var batteryMaxTempC: Double?
    var batteryMinTempC: Double?
    var batteryCoolantTempC: Double?
    var hvacMeasuredPowerW: Double?
    var hvacCommandedPowerW: Double?
    var acCompressorOn: Bool?
    var batteryCapacityAh: Double?
    var batteryResistanceMOhm: Double?

    // Tracking
    var syncedToDatabricks: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case soc
        case speedKmh
        case currentAmps
        case voltageVolts
        case distanceMi
        case ambientTempF
        case socHD
        case batteryAvgTempC
        case batteryMaxTempC
        case batteryMinTempC
        case batteryCoolantTempC
        case hvacMeasuredPowerW
        case hvacCommandedPowerW
        case acCompressorOn
        case batteryCapacityAh
        case batteryResistanceMOhm
        case syncedToDatabricks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.soc = try container.decodeIfPresent(Double.self, forKey: .soc)
        self.speedKmh = try container.decodeIfPresent(Int.self, forKey: .speedKmh)
        self.currentAmps = try container.decodeIfPresent(Double.self, forKey: .currentAmps)
        self.voltageVolts = try container.decodeIfPresent(Double.self, forKey: .voltageVolts)
        self.distanceMi = try container.decodeIfPresent(Double.self, forKey: .distanceMi)
        self.ambientTempF = try container.decodeIfPresent(Double.self, forKey: .ambientTempF)
        self.socHD = try container.decodeIfPresent(Double.self, forKey: .socHD)
        self.batteryAvgTempC = try container.decodeIfPresent(Double.self, forKey: .batteryAvgTempC)
        self.batteryMaxTempC = try container.decodeIfPresent(Double.self, forKey: .batteryMaxTempC)
        self.batteryMinTempC = try container.decodeIfPresent(Double.self, forKey: .batteryMinTempC)
        self.batteryCoolantTempC = try container.decodeIfPresent(Double.self, forKey: .batteryCoolantTempC)
        self.hvacMeasuredPowerW = try container.decodeIfPresent(Double.self, forKey: .hvacMeasuredPowerW)
        self.hvacCommandedPowerW = try container.decodeIfPresent(Double.self, forKey: .hvacCommandedPowerW)
        self.acCompressorOn = try container.decodeIfPresent(Bool.self, forKey: .acCompressorOn)
        self.batteryCapacityAh = try container.decodeIfPresent(Double.self, forKey: .batteryCapacityAh)
        self.batteryResistanceMOhm = try container.decodeIfPresent(Double.self, forKey: .batteryResistanceMOhm)
        self.syncedToDatabricks = try container.decodeIfPresent(Bool.self, forKey: .syncedToDatabricks) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(soc, forKey: .soc)
        try container.encodeIfPresent(speedKmh, forKey: .speedKmh)
        try container.encodeIfPresent(currentAmps, forKey: .currentAmps)
        try container.encodeIfPresent(voltageVolts, forKey: .voltageVolts)
        try container.encodeIfPresent(distanceMi, forKey: .distanceMi)
        try container.encodeIfPresent(ambientTempF, forKey: .ambientTempF)
        try container.encodeIfPresent(socHD, forKey: .socHD)
        try container.encodeIfPresent(batteryAvgTempC, forKey: .batteryAvgTempC)
        try container.encodeIfPresent(batteryMaxTempC, forKey: .batteryMaxTempC)
        try container.encodeIfPresent(batteryMinTempC, forKey: .batteryMinTempC)
        try container.encodeIfPresent(batteryCoolantTempC, forKey: .batteryCoolantTempC)
        try container.encodeIfPresent(hvacMeasuredPowerW, forKey: .hvacMeasuredPowerW)
        try container.encodeIfPresent(hvacCommandedPowerW, forKey: .hvacCommandedPowerW)
        try container.encodeIfPresent(acCompressorOn, forKey: .acCompressorOn)
        try container.encodeIfPresent(batteryCapacityAh, forKey: .batteryCapacityAh)
        try container.encodeIfPresent(batteryResistanceMOhm, forKey: .batteryResistanceMOhm)
        try container.encode(syncedToDatabricks, forKey: .syncedToDatabricks)
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
        let speed = speedKmh?.description ?? ""
        let current = currentAmps?.description ?? ""
        let voltage = voltageVolts?.description ?? ""
        let distance = distanceMi?.description ?? ""
        let ambient = ambientTempF?.description ?? ""
        let socHDStr = socHD?.description ?? ""
        let battAvgTemp = batteryAvgTempC?.description ?? ""
        let battMaxTemp = batteryMaxTempC?.description ?? ""
        let battMinTemp = batteryMinTempC?.description ?? ""
        let coolantTemp = batteryCoolantTempC?.description ?? ""
        let hvacMeasured = hvacMeasuredPowerW?.description ?? ""
        let hvacCommanded = hvacCommandedPowerW?.description ?? ""
        let acOn = acCompressorOn.map { $0 ? "1" : "0" } ?? ""
        let capacity = batteryCapacityAh?.description ?? ""
        let resistance = batteryResistanceMOhm?.description ?? ""

        return [timestamp, soc, speed, current, voltage, distance, ambient,
                socHDStr, battAvgTemp, battMaxTemp, battMinTemp, coolantTemp,
                hvacMeasured, hvacCommanded, acOn, capacity, resistance].joined(separator: ",")
    }

    static var csvHeader: String {
        return "timestamp,soc,speed_kmh,current_amps,voltage_volts,distance_mi,ambient_temp_f," +
               "soc_hd,battery_avg_temp_c,battery_max_temp_c,battery_min_temp_c,battery_coolant_temp_c," +
               "hvac_measured_power_w,hvac_commanded_power_w,ac_compressor_on,battery_capacity_ah,battery_resistance_mohm"
    }
}
