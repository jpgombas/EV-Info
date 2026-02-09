//
//  EV_InfoApp.swift
//  EV Info
//
//  Created by Jason on 8/29/25.
//

import SwiftUI

@main
struct EV_InfoApp: App {
    @StateObject private var dataStore: DataStore
    @StateObject private var syncManager: SyncManager

    init() {
        let dataStore = DataStore()
        _dataStore = StateObject(wrappedValue: dataStore)

        // Load Databricks configuration from UserDefaults
        let workspaceURL = UserDefaults.standard.string(forKey: "databricksWorkspaceURL") ?? ""
        let keychain = DatabricksKeychain()
        let accessToken = keychain.loadToken(for: "databricksAccessToken") ?? ""
        let volumePath = UserDefaults.standard.string(forKey: "databricksVolumePath")
        let sqlWarehouseID = UserDefaults.standard.string(forKey: "databricksSQLWarehouseID")
        let tableName = UserDefaults.standard.string(forKey: "databricksTableName")

        let config = DatabricksClient.Config(
            workspaceURL: workspaceURL,
            accessToken: accessToken,
            volumePath: volumePath,
            sqlWarehouseID: sqlWarehouseID,
            tableName: tableName,
            oauthClientId: AppSecrets.oauthClientId,
            oauthClientSecret: AppSecrets.oauthClientSecret
        )

        let client = DatabricksClient(config: config)
        _syncManager = StateObject(wrappedValue: SyncManager(databricksClient: client, dataStore: dataStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dataStore: dataStore, syncManager: syncManager)
        }
    }
}
