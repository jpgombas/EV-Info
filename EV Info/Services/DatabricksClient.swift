import Foundation

/// Client for interacting with Databricks REST API
class DatabricksClient {
    
    // MARK: - Configuration
    struct Config {
        let workspaceURL: String  // e.g., "https://your-workspace.cloud.databricks.com"
        let accessToken: String   // Personal Access Token
        let volumePath: String?   // Optional: Unity Catalog volume path
        let sqlWarehouseID: String? // Optional: SQL Warehouse endpoint
        let tableName: String?    // Optional: Target table name
        
        var isValid: Bool {
            return !workspaceURL.isEmpty && !accessToken.isEmpty
        }
    }
    
    private var config: Config
    
    init(config: Config) {
        self.config = config
    }
    
    // MARK: - Upload Methods
    
    /// Upload data as CSV file to Unity Catalog volume
    func uploadCSVToVolume(data: [VehicleDataPoint]) async throws -> UploadResponse {
        print("DEBUG: uploadCSVToVolume - Config valid: \(config.isValid)")
        print("DEBUG: workspaceURL: \(config.workspaceURL.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: accessToken: \(config.accessToken.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: volumePath: \(config.volumePath?.isEmpty == false ? "PRESENT" : "EMPTY/NIL")")
        
        guard config.isValid, let volumePath = config.volumePath else {
            print("DEBUG: Configuration invalid. isValid=\(config.isValid), volumePath=\(config.volumePath != nil)")
            throw DatabricksError.invalidConfiguration
        }
        
        // Convert data to CSV
        let csv = convertToCSV(data: data)
        guard let csvData = csv.data(using: .utf8) else {
            throw DatabricksError.dataConversionFailed
        }
        
        // Generate filename with timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "vehicle_data_\(timestamp).csv"
        let uploadPath = "\(volumePath)/\(filename)"
        
        // Prepare request (Files API PUT endpoint)
        let url = URL(string: "\(config.workspaceURL)/api/2.0/fs/files\(uploadPath)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        request.httpBody = csvData
        
        // Execute request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabricksError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return UploadResponse(success: true,
                                recordCount: data.count,
                                path: uploadPath,
                                message: "Successfully uploaded to \(uploadPath)")
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.uploadFailed(statusCode: httpResponse.statusCode,
                                              message: errorMessage)
        }
    }
    
    /// Upload data using SQL INSERT statements
    func uploadViaSQLWarehouse(data: [VehicleDataPoint]) async throws -> UploadResponse {
        print("DEBUG: uploadViaSQLWarehouse - Config valid: \(config.isValid)")
        print("DEBUG: workspaceURL: \(config.workspaceURL.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: accessToken: \(config.accessToken.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: sqlWarehouseID: \(config.sqlWarehouseID?.isEmpty == false ? "PRESENT" : "EMPTY/NIL")")
        print("DEBUG: tableName: \(config.tableName?.isEmpty == false ? "PRESENT" : "EMPTY/NIL")")
        
        guard config.isValid,
              let warehouseID = config.sqlWarehouseID,
              let tableName = config.tableName else {
            print("DEBUG: Configuration invalid")
            throw DatabricksError.invalidConfiguration
        }
        
        // Generate INSERT statement
        let insertSQL = generateInsertSQL(data: data, tableName: tableName)
        
        // Prepare request
        let url = URL(string: "\(config.workspaceURL)/api/2.0/sql/statements")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "warehouse_id": warehouseID,
            "statement": insertSQL,
            "wait_timeout": "30s"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Execute request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabricksError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return UploadResponse(success: true,
                                recordCount: data.count,
                                path: tableName,
                                message: "Successfully inserted \(data.count) records")
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.uploadFailed(statusCode: httpResponse.statusCode,
                                              message: errorMessage)
        }
    }
    
    /// Upload data as JSON to volume (alternative method)
    func uploadJSONToVolume(data: [VehicleDataPoint]) async throws -> UploadResponse {
        print("DEBUG: uploadJSONToVolume - Config valid: \(config.isValid)")
        print("DEBUG: workspaceURL: \(config.workspaceURL.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: accessToken: \(config.accessToken.isEmpty ? "EMPTY" : "PRESENT")")
        print("DEBUG: volumePath: \(config.volumePath?.isEmpty == false ? "PRESENT" : "EMPTY/NIL")")
        
        guard config.isValid, let volumePath = config.volumePath else {
            print("DEBUG: Configuration invalid")
            throw DatabricksError.invalidConfiguration
        }
        
        // Convert data to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        
        // Generate filename with timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "vehicle_data_\(timestamp).json"
        let uploadPath = "\(volumePath)/\(filename)"
        
        // Prepare request
        let url = URL(string: "\(config.workspaceURL)/api/2.0/fs/files\(uploadPath)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Execute request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabricksError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return UploadResponse(success: true,
                                recordCount: data.count,
                                path: uploadPath,
                                message: "Successfully uploaded to \(uploadPath)")
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.uploadFailed(statusCode: httpResponse.statusCode,
                                              message: errorMessage)
        }
    }
    
    // MARK: - Validation
    
    /// Test connection to Databricks
    func testConnection() async throws -> Bool {
        let url = URL(string: "\(config.workspaceURL)/api/2.0/clusters/list")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Helper Methods
    
    private func convertToCSV(data: [VehicleDataPoint]) -> String {
        var csv = VehicleDataPoint.csvHeader + "\n"
        csv += data.map { $0.toCSVRow() }.joined(separator: "\n")
        return csv
    }
    
    private func generateInsertSQL(data: [VehicleDataPoint], tableName: String) -> String {
        let formatter = ISO8601DateFormatter()
        
        let values = data.map { dataPoint -> String in
            let timestamp = "'\(formatter.string(from: dataPoint.timestamp))'"
            let soc = dataPoint.soc?.description ?? "NULL"
            let capacity = dataPoint.batteryCapacityKWh?.description ?? "NULL"
            let tempC = dataPoint.batteryTempCelsius?.description ?? "NULL"
            let tempF = dataPoint.batteryTempFahrenheit?.description ?? "NULL"
            let charging = dataPoint.isCharging?.description.uppercased() ?? "NULL"
            let speed = dataPoint.speedKmh?.description ?? "NULL"
            let current = dataPoint.currentAmps?.description ?? "NULL"
            let voltage = dataPoint.voltageVolts?.description ?? "NULL"
            let acPower = dataPoint.cabinACPowerWatts?.description ?? "NULL"
            let heatPower = dataPoint.cabinHeatPowerWatts?.description ?? "NULL"
            let transmission = dataPoint.transmissionPosition?.description ?? "NULL"
            let distance = dataPoint.distanceMi?.description ?? "NULL"
            let ambient = dataPoint.ambientTempF?.description ?? "NULL"
            
            return "(\(timestamp), \(soc), \(capacity), \(tempC), \(tempF), \(charging), \(speed), \(current), \(voltage), \(acPower), \(heatPower), \(transmission), \(distance), \(ambient))"
        }.joined(separator: ",\n")
        
        return """
        INSERT INTO \(tableName)
        (timestamp, soc, battery_capacity_kwh, battery_temp_celsius, battery_temp_fahrenheit,
         is_charging, speed_kmh, current_amps, voltage_volts, cabin_ac_power_watts,
         cabin_heat_power_watts, transmission_position, distance_mi, ambient_temp_f)
        VALUES
        \(values)
        """
    }
}

// MARK: - Response Models

struct UploadResponse {
    let success: Bool
    let recordCount: Int
    let path: String
    let message: String
}

// MARK: - Errors

enum DatabricksError: LocalizedError {
    case invalidConfiguration
    case dataConversionFailed
    case invalidResponse
    case uploadFailed(statusCode: Int, message: String)
    case authenticationFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Databricks configuration is invalid or incomplete"
        case .dataConversionFailed:
            return "Failed to convert data for upload"
        case .invalidResponse:
            return "Received invalid response from Databricks"
        case .uploadFailed(let statusCode, let message):
            return "Upload failed with status \(statusCode): \(message)"
        case .authenticationFailed:
            return "Authentication failed. Check your access token."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Keychain Helper for Secure Token Storage

class DatabricksKeychain {
    
    private let service = "com.evinfo.databricks"
    
    func saveToken(_ token: String, for key: String) -> Bool {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func loadToken(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
