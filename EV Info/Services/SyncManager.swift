import Foundation
import Combine
import Network

/// Manages synchronization of vehicle data to Databricks
class SyncManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var pendingRecordCount = 0
    @Published var totalSyncedRecords = 0
    @Published var lastSyncError: String?
    
    // MARK: - Private Properties
    private var databricksClient: DatabricksClient
    private let dataStore: DataStore
    private var syncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 300 // 5 minutes
    private let networkMonitor = NetworkMonitor()
    
    // Settings
    var autoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncEnabled, forKey: "autoSyncEnabled")
            if autoSyncEnabled {
                startAutoSync()
            } else {
                stopAutoSync()
            }
        }
    }
    
    var syncOnlyOnWiFi: Bool {
        didSet {
            UserDefaults.standard.set(syncOnlyOnWiFi, forKey: "syncOnlyOnWiFi")
        }
    }
    
    var batchSize: Int {
        didSet {
            UserDefaults.standard.set(batchSize, forKey: "syncBatchSize")
        }
    }
    
    var uploadMethod: UploadMethod {
        didSet {
            UserDefaults.standard.set(uploadMethod.rawValue, forKey: "uploadMethod")
        }
    }
    
    enum UploadMethod: String {
        case csv = "csv"
        case json = "json"
        case sqlWarehouse = "sqlWarehouse"
    }
    
    // MARK: - Initialization
    init(databricksClient: DatabricksClient, dataStore: DataStore) {
        self.databricksClient = databricksClient
        self.dataStore = dataStore
        
        // Load settings
        self.autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
        self.syncOnlyOnWiFi = UserDefaults.standard.bool(forKey: "syncOnlyOnWiFi")
        self.batchSize = UserDefaults.standard.integer(forKey: "syncBatchSize")
        
        if let methodString = UserDefaults.standard.string(forKey: "uploadMethod"),
           let method = UploadMethod(rawValue: methodString) {
            self.uploadMethod = method
        } else {
            self.uploadMethod = .csv
        }
        
        // Default values
        if batchSize == 0 {
            batchSize = 100
        }
        
        // Load last sync time
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date {
            self.lastSyncTime = timestamp
        }
        
        // Start auto sync if enabled
        if autoSyncEnabled {
            startAutoSync()
        }
        
        // Update pending count
        updatePendingCount()
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger a sync
    func syncNow() async {
        await performSync()
    }
    
    /// Start automatic syncing
    func startAutoSync() {
        stopAutoSync() // Stop any existing timer
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }
    
    /// Stop automatic syncing
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Update the count of pending records
    func updatePendingCount() {
        pendingRecordCount = dataStore.getUnsyncedRecordCount()
    }
    
    /// Update Databricks client configuration (call this when settings are saved)
    func updateDatabricksConfig(workspaceURL: String, accessToken: String, volumePath: String?, sqlWarehouseID: String?, tableName: String?) {
        let config = DatabricksClient.Config(
            workspaceURL: workspaceURL,
            accessToken: accessToken,
            volumePath: volumePath?.isEmpty == false ? volumePath : nil,
            sqlWarehouseID: sqlWarehouseID?.isEmpty == false ? sqlWarehouseID : nil,
            tableName: tableName?.isEmpty == false ? tableName : nil
        )
        self.databricksClient = DatabricksClient(config: config)
    }
    
    // MARK: - Private Methods
    
    private func performSync() async {
        // Prevent concurrent syncs
        guard !isSyncing else { return }
        
        // Check WiFi requirement
        if syncOnlyOnWiFi && !networkMonitor.isOnWiFi {
            print("Skipping sync: WiFi required but not connected")
            return
        }
        
        // Check if there's data to sync
        updatePendingCount()
        guard pendingRecordCount > 0 else {
            print("No pending records to sync")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            lastSyncError = nil
        }
        
        do {
            // Get unsynced records
            let unsyncedRecords = dataStore.getUnsyncedRecords(limit: batchSize)
            
            guard !unsyncedRecords.isEmpty else {
                await finishSync(success: true, error: nil)
                return
            }
            
            print("DEBUG: Attempting to sync \(unsyncedRecords.count) records...")
            print("DEBUG: Upload method: \(uploadMethod)")
            
            // Upload to Databricks using configured method
            let response = try await uploadData(unsyncedRecords)
            
            if response.success {
                // Mark records as synced
                dataStore.markRecordsAsSynced(unsyncedRecords.map { $0.id })
                
                await MainActor.run {
                    totalSyncedRecords += unsyncedRecords.count
                    print("Successfully synced \(unsyncedRecords.count) records")
                }
                
                await finishSync(success: true, error: nil)
                
                // If there are more records, sync again
                updatePendingCount()
                if pendingRecordCount > 0 {
                    // Small delay before next batch
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await performSync()
                }
            } else {
                await finishSync(success: false, error: "Upload failed: \(response.message)")
            }
            
        } catch {
            await finishSync(success: false, error: error.localizedDescription)
        }
    }
    
    private func uploadData(_ data: [VehicleDataPoint]) async throws -> UploadResponse {
        switch uploadMethod {
        case .csv:
            print("DEBUG: Uploading CSV using databricksClient")
            return try await databricksClient.uploadCSVToVolume(data: data)
        case .json:
            print("DEBUG: Uploading JSON using databricksClient")
            return try await databricksClient.uploadJSONToVolume(data: data)
        case .sqlWarehouse:
            print("DEBUG: Uploading via SQL Warehouse using databricksClient")
            return try await databricksClient.uploadViaSQLWarehouse(data: data)
        }
    }
    
    private func finishSync(success: Bool, error: String?) async {
        await MainActor.run {
            isSyncing = false
            
            if success {
                lastSyncTime = Date()
                UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
                lastSyncError = nil
            } else {
                lastSyncError = error
            }
            
            updatePendingCount()
        }
    }
    
    // MARK: - Retry Logic
    
    /// Retry failed syncs with exponential backoff
    func retryFailedSync(attempt: Int = 1, maxAttempts: Int = 3) async {
        let backoffDelay = TimeInterval(pow(2.0, Double(attempt))) // 2^attempt seconds
        
        print("Retry attempt \(attempt) after \(backoffDelay)s delay...")
        
        try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
        
        await performSync()
        
        // Check if sync was successful
        if lastSyncError != nil && attempt < maxAttempts {
            await retryFailedSync(attempt: attempt + 1, maxAttempts: maxAttempts)
        }
    }
}

// MARK: - Network Type Detection Helper

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var isExpensive = false
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var isOnWiFi = false
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                    self?.isOnWiFi = true
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                    self?.isOnWiFi = false
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wiredEthernet
                    self?.isOnWiFi = true
                } else {
                    self?.connectionType = nil
                    self?.isOnWiFi = false
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
