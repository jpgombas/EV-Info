import Foundation

/// Enhanced data point structure for Databricks storage
/// Compatible with both existing VehicleData and cloud synchronization
struct VehicleDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    
    // Vehicle telemetry
    var soc: Double? // State of charge (%)
    var speedKmh: Int?
    var currentAmps: Double?
    var voltageVolts: Double?
    var distanceMi: Double?
    var ambientTempF: Double?
    
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
        let speed = speedKmh?.description ?? ""
        let current = currentAmps?.description ?? ""
        let voltage = voltageVolts?.description ?? ""
        let distance = distanceMi?.description ?? ""
        let ambient = ambientTempF?.description ?? ""
        
        return [timestamp, soc, speed, current, voltage, distance, ambient].joined(separator: ",")
    }
    
    static var csvHeader: String {
        return "timestamp,soc,speed_kmh,current_amps,voltage_volts,distance_mi,ambient_temp_f"
    }
}

