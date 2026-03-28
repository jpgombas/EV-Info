import Foundation

// MARK: - App Constants

enum Constants {

    enum BLE {
        static let targetDeviceName = "VEEPEAK"
    }

    enum OBD2 {
        static let defaultDataTimerDuration: TimeInterval = 0.8
        static let slowCycleInterval = 10
        static let tripPollInterval: TimeInterval = 600  // 10 minutes
        static let initTimeoutSeconds: TimeInterval = 3.0
        static let responseTimeoutSeconds: TimeInterval = 2.5
        static let postInitDelay: TimeInterval = 2.0
        static let interInitCommandDelay: TimeInterval = 0.5
        static let maxResponseBufferSize = 4096
    }

    enum Sync {
        static let autoSyncInterval: TimeInterval = 300  // 5 minutes
        static let defaultBatchSize = 100
        static let interBatchDelayNanoseconds: UInt64 = 2_000_000_000  // 2 seconds
    }

    enum DataStore {
        static let recentDataPointsLimit = 100
    }

    enum Logger {
        static let maxMessages = 30
    }
}

// MARK: - UserDefaults Keys

enum UserDefaultsKey {
    static let databricksWorkspaceURL = "databricksWorkspaceURL"
    static let databricksVolumePath = "databricksVolumePath"
    static let databricksSQLWarehouseID = "databricksSQLWarehouseID"
    static let databricksTableName = "databricksTableName"
    static let autoSyncEnabled = "autoSyncEnabled"
    static let syncOnlyOnWiFi = "syncOnlyOnWiFi"
    static let syncBatchSize = "syncBatchSize"
    static let uploadMethod = "uploadMethod"
    static let lastSyncTime = "lastSyncTime"
    static let totalSyncedRecords = "totalSyncedRecords"
}
