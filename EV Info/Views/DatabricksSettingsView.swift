import SwiftUI

struct DatabricksSettingsView: View {
    @ObservedObject var syncManager: SyncManager
    @ObservedObject var networkMonitor: NetworkMonitor
    
    @State private var workspaceURL = "https://dbc-44b8c99f-a387.cloud.databricks.com"
    @State private var accessToken = "REDACTED_DATABRICKS_API_TOKEN"
    @State private var volumePath = "/Volumes/vehicle_data/telemetry/uploads"
    @State private var sqlWarehouseID = ""
    @State private var tableName = ""
    
    @State private var testingCSVUpload = false
    @State private var csvUploadResult: String?
    
    @State private var testingConnection = false
    @State private var connectionTestResult: String?
    @State private var showingSuccess = false
    
    private let keychain = DatabricksKeychain()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Databricks Configuration")) {
                    TextField("Workspace URL", text: $workspaceURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textCase(.lowercase)
                    
                    SecureField("Access Token", text: $accessToken)
                    
                    Picker("Upload Method", selection: $syncManager.uploadMethod) {
                        Text("CSV File").tag(SyncManager.UploadMethod.csv)
                        Text("JSON File").tag(SyncManager.UploadMethod.json)
                        Text("SQL Warehouse").tag(SyncManager.UploadMethod.sqlWarehouse)
                    }
                }
                
                if syncManager.uploadMethod == .csv || syncManager.uploadMethod == .json {
                    Section(header: Text("Volume Configuration")) {
                        TextField("Volume Path", text: $volumePath)
                            .autocorrectionDisabled()
                            .textContentType(.URL)
                    }
                }
                
                if syncManager.uploadMethod == .sqlWarehouse {
                    Section(header: Text("SQL Warehouse Configuration")) {
                        TextField("Warehouse ID", text: $sqlWarehouseID)
                            .autocorrectionDisabled()
                        
                        TextField("Table Name", text: $tableName)
                            .autocorrectionDisabled()
                    }
                }
                
                Section(header: Text("Sync Settings")) {
                    Toggle("Auto Sync Enabled", isOn: $syncManager.autoSyncEnabled)
                    
                    Toggle("WiFi Only", isOn: $syncManager.syncOnlyOnWiFi)
                        .help("Only sync when connected to WiFi")
                    
                    Stepper("Batch Size: \(syncManager.batchSize)", value: $syncManager.batchSize, in: 10...1000, step: 10)
                }
                
                Section(header: Text("Status")) {
                    HStack {
                        Text("Pending Records")
                        Spacer()
                        Text("\(syncManager.pendingRecordCount)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Total Synced")
                        Spacer()
                        Text("\(syncManager.totalSyncedRecords)")
                            .fontWeight(.semibold)
                    }
                    
                    if let lastSync = syncManager.lastSyncTime {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("Network")
                        Spacer()
                        if networkMonitor.isConnected {
                            if networkMonitor.isOnWiFi {
                                Label("WiFi", systemImage: "wifi")
                                    .foregroundColor(.green)
                            } else {
                                Label("Cellular", systemImage: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Label("Offline", systemImage: "wifi.slash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let error = syncManager.lastSyncError {
                        VStack(alignment: .leading) {
                            Text("Last Error")
                                .fontWeight(.semibold)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button(action: { testConnection() }) {
                        HStack {
                            if testingConnection {
                                ProgressView()
                            }
                            Text("Test Connection")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(testingConnection || workspaceURL.isEmpty || accessToken.isEmpty)
                    
                    if let result = connectionTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                    
                    Button(action: { testCSVUpload() }) {
                        HStack {
                            if testingCSVUpload {
                                ProgressView()
                            }
                            Text("Test CSV Upload")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(testingCSVUpload || workspaceURL.isEmpty || accessToken.isEmpty || volumePath.isEmpty)
                    
                    if let result = csvUploadResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await syncManager.syncNow()
                        }
                    }) {
                        HStack {
                            if syncManager.isSyncing {
                                ProgressView()
                            }
                            Text("Sync Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(syncManager.isSyncing || syncManager.pendingRecordCount == 0)
                }
                
                Section(header: Text("Debug Info")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UI State Values:")
                            .fontWeight(.semibold)
                        Text("URL: \(workspaceURL.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                        Text("Token: \(accessToken.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                        Text("Volume: \(volumePath.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                        
                        Divider()
                        
                        Text("UserDefaults Values:")
                            .fontWeight(.semibold)
                        let savedURL = UserDefaults.standard.string(forKey: "databricksWorkspaceURL") ?? "NOT SET"
                        let savedToken = (DatabricksKeychain().loadToken(for: "databricksAccessToken") ?? "NOT SET")
                        let savedVolume = UserDefaults.standard.string(forKey: "databricksVolumePath") ?? "NOT SET"
                        
                        Text("URL: \(savedURL.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                        Text("Token: \(savedToken.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                        Text("Volume: \(savedVolume.isEmpty ? "EMPTY" : "SET")")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: { saveConfiguration() }) {
                        Text("Save Configuration")
                            .fontWeight(.semibold)
                    }
                    .disabled(workspaceURL.isEmpty || accessToken.isEmpty)
                }
            }
            .navigationTitle("Databricks Settings")
            .onAppear {
                loadConfiguration()
                syncManager.updatePendingCount()
            }
            .alert("Configuration Saved", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your Databricks configuration has been saved securely.")
            }
        }
    }
    
    private func loadConfiguration() {
        if let savedURL = UserDefaults.standard.string(forKey: "databricksWorkspaceURL") {
            workspaceURL = savedURL
        }
        
        if let token = keychain.loadToken(for: "databricksAccessToken") {
            accessToken = token
        }
        
        if let savedPath = UserDefaults.standard.string(forKey: "databricksVolumePath") {
            volumePath = savedPath
        }
        
        if let savedWarehouse = UserDefaults.standard.string(forKey: "databricksSQLWarehouseID") {
            sqlWarehouseID = savedWarehouse
        }
        
        if let savedTable = UserDefaults.standard.string(forKey: "databricksTableName") {
            tableName = savedTable
        }
    }
    
    private func saveConfiguration() {
        UserDefaults.standard.set(workspaceURL, forKey: "databricksWorkspaceURL")
        keychain.saveToken(accessToken, for: "databricksAccessToken")
        UserDefaults.standard.set(volumePath, forKey: "databricksVolumePath")
        UserDefaults.standard.set(sqlWarehouseID, forKey: "databricksSQLWarehouseID")
        UserDefaults.standard.set(tableName, forKey: "databricksTableName")
        
        // Update SyncManager with new configuration
        syncManager.updateDatabricksConfig(
            workspaceURL: workspaceURL,
            accessToken: accessToken,
            volumePath: volumePath,
            sqlWarehouseID: sqlWarehouseID,
            tableName: tableName
        )
        
        showingSuccess = true
    }
    
    private func testConnection() {
        testingConnection = true
        
        let config = DatabricksClient.Config(
            workspaceURL: workspaceURL,
            accessToken: accessToken,
            volumePath: volumePath.isEmpty ? nil : volumePath,
            sqlWarehouseID: sqlWarehouseID.isEmpty ? nil : sqlWarehouseID,
            tableName: tableName.isEmpty ? nil : tableName
        )
        
        let client = DatabricksClient(config: config)
        
        Task {
            do {
                let isConnected = try await client.testConnection()
                await MainActor.run {
                    testingConnection = false
                    connectionTestResult = isConnected ? "✓ Connection successful!" : "✗ Connection failed"
                }
            } catch {
                await MainActor.run {
                    testingConnection = false
                    connectionTestResult = "✗ Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func testCSVUpload() {
        testingCSVUpload = true
        csvUploadResult = nil
        
        let config = DatabricksClient.Config(
            workspaceURL: workspaceURL,
            accessToken: accessToken,
            volumePath: volumePath.isEmpty ? nil : volumePath,
            sqlWarehouseID: sqlWarehouseID.isEmpty ? nil : sqlWarehouseID,
            tableName: tableName.isEmpty ? nil : tableName
        )
        
        let client = DatabricksClient(config: config)
        
        Task {
            do {
                let testData = VehicleDataPoint(timestamp: Date())
                _ = try await client.uploadCSVToVolume(data: [testData])
                await MainActor.run {
                    testingCSVUpload = false
                    csvUploadResult = "✓ CSV upload successful!"
                }
            } catch {
                await MainActor.run {
                    testingCSVUpload = false
                    csvUploadResult = "✗ Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    let dataStore = DataStore()
    let config = DatabricksClient.Config(
        workspaceURL: "https://example.cloud.databricks.com",
        accessToken: "dapi...",
        volumePath: "/Volumes/catalog/schema/volume",
        sqlWarehouseID: nil,
        tableName: nil
    )
    let client = DatabricksClient(config: config)
    let syncManager = SyncManager(databricksClient: client, dataStore: dataStore)
    
    return DatabricksSettingsView(syncManager: syncManager, networkMonitor: NetworkMonitor())
}
