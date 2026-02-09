import Foundation

/// Client for interacting with Databricks REST API
class DatabricksClient {
    
    // MARK: - Configuration
    struct Config {
        let workspaceURL: String  // e.g., "https://your-workspace.cloud.databricks.com"
        let accessToken: String   // Personal Access Token (for API calls)
        let volumePath: String?   // Optional: Unity Catalog volume path
        let sqlWarehouseID: String? // Optional: SQL Warehouse endpoint
        let tableName: String?    // Optional: Target table name
        
        // OAuth credentials for dashboard embedding
        let oauthClientId: String?     // Service Principal client ID
        let oauthClientSecret: String? // Service Principal OAuth secret
        
        var isValid: Bool {
            return !workspaceURL.isEmpty && !accessToken.isEmpty
        }
        
        var hasOAuthCredentials: Bool {
            return oauthClientId != nil && oauthClientSecret != nil
        }
    }
    
    @Published var config: Config
    
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
    
    /// Generate a dashboard-scoped OAuth token for embedding (3-step flow)
    func generateEmbeddingToken(dashboardId: String, externalViewerId: String? = nil, externalValue: String? = nil) async throws -> EmbeddingTokenResponse {
        guard config.hasOAuthCredentials,
              let clientId = config.oauthClientId,
              let clientSecret = config.oauthClientSecret else {
            throw DatabricksError.invalidConfiguration
        }

        let basicAuth: String = {
            let credentials = "\(clientId):\(clientSecret)"
            return "Basic \(credentials.data(using: .utf8)!.base64EncodedString())"
        }()

        // Step 1: Get a broad all-apis token via client_credentials
        let step1URL = URL(string: "\(config.workspaceURL)/oidc/v1/token")!
        var step1Request = URLRequest(url: step1URL)
        step1Request.httpMethod = "POST"
        step1Request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        step1Request.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        step1Request.httpBody = "grant_type=client_credentials&scope=all-apis".data(using: .utf8)

        let (step1Data, step1Response) = try await URLSession.shared.data(for: step1Request)
        guard let step1Http = step1Response as? HTTPURLResponse,
              step1Http.statusCode >= 200 && step1Http.statusCode < 300 else {
            let msg = String(data: step1Data, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.authenticationFailed(message: "Step 1 failed: \(msg)")
        }
        let step1Token = try JSONDecoder().decode(EmbeddingTokenResponse.self, from: step1Data)

        // Step 2: Call /tokeninfo to get authorization_details scoped to the dashboard
        var step2Components = URLComponents(string: "\(config.workspaceURL)/api/2.0/lakeview/dashboards/\(dashboardId)/published/tokeninfo")!
        var queryItems: [URLQueryItem] = []
        if let viewerId = externalViewerId {
            queryItems.append(URLQueryItem(name: "external_viewer_id", value: viewerId))
        }
        if let value = externalValue {
            queryItems.append(URLQueryItem(name: "external_value", value: value))
        }
        if !queryItems.isEmpty {
            step2Components.queryItems = queryItems
        }

        var step2Request = URLRequest(url: step2Components.url!)
        step2Request.httpMethod = "GET"
        step2Request.setValue("Bearer \(step1Token.accessToken)", forHTTPHeaderField: "Authorization")

        let (step2Data, step2Response) = try await URLSession.shared.data(for: step2Request)
        guard let step2Http = step2Response as? HTTPURLResponse,
              step2Http.statusCode >= 200 && step2Http.statusCode < 300 else {
            let msg = String(data: step2Data, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.authenticationFailed(message: "Step 2 (tokeninfo) failed: \(msg)")
        }

        // Parse the authorization_details JSON from the tokeninfo response
        guard let tokenInfo = try JSONSerialization.jsonObject(with: step2Data) as? [String: Any],
              let authorizationDetails = tokenInfo["authorization_details"] else {
            throw DatabricksError.invalidResponse
        }
        let authDetailsJSON = try JSONSerialization.data(withJSONObject: authorizationDetails)
        let authDetailsString = String(data: authDetailsJSON, encoding: .utf8) ?? "[]"

        // Step 3: Generate a tightly-scoped token using the authorization_details
        let step3URL = URL(string: "\(config.workspaceURL)/oidc/v1/token")!
        var step3Request = URLRequest(url: step3URL)
        step3Request.httpMethod = "POST"
        step3Request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        step3Request.setValue(basicAuth, forHTTPHeaderField: "Authorization")

        let encodedAuthDetails = authDetailsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let step3FormData = "grant_type=client_credentials&authorization_details=\(encodedAuthDetails)"
        step3Request.httpBody = step3FormData.data(using: .utf8)

        let (step3Data, step3Response) = try await URLSession.shared.data(for: step3Request)
        guard let step3Http = step3Response as? HTTPURLResponse,
              step3Http.statusCode >= 200 && step3Http.statusCode < 300 else {
            let msg = String(data: step3Data, encoding: .utf8) ?? "Unknown error"
            throw DatabricksError.authenticationFailed(message: "Step 3 (scoped token) failed: \(msg)")
        }

        let scopedToken = try JSONDecoder().decode(EmbeddingTokenResponse.self, from: step3Data)
        return scopedToken
    }
    
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
            let speed = dataPoint.speedKmh?.description ?? "NULL"
            let current = dataPoint.currentAmps?.description ?? "NULL"
            let voltage = dataPoint.voltageVolts?.description ?? "NULL"
            let distance = dataPoint.distanceMi?.description ?? "NULL"
            let ambient = dataPoint.ambientTempF?.description ?? "NULL"
            
            return "(\(timestamp), \(soc), \(speed), \(current), \(voltage), \(distance), \(ambient))"
        }.joined(separator: ",\n")
        
        return """
        INSERT INTO \(tableName)
        (timestamp, soc, speed_kmh, current_amps, voltage_volts, distance_mi, ambient_temp_f)
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

struct EmbeddingTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Errors

enum DatabricksError: LocalizedError {
    case invalidConfiguration
    case dataConversionFailed
    case invalidResponse
    case uploadFailed(statusCode: Int, message: String)
    case authenticationFailed(message: String)
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
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
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
