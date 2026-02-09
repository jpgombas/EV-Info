//
//  ContentView.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import SwiftUI

enum AppView: String, CaseIterable {
    case dashboard = "Dash"
    case details = "Details"
    case settings = "Settings"
}

struct ContentView: View {
    @StateObject private var logger = Logger()
    @StateObject private var connection: BLEConnection
    @StateObject private var controller: OBD2Controller
    @State private var selectedView: AppView = .dashboard
    
    let dataStore: DataStore
    let syncManager: SyncManager
    
    init(dataStore: DataStore, syncManager: SyncManager) {
        let logger = Logger()
        let connection = BLEConnection(logger: logger)
        let parser = OBD2Parser(logger: logger)
        let controller = OBD2Controller(connection: connection, parser: parser, logger: logger, dataStore: dataStore)
        
        self._logger = StateObject(wrappedValue: logger)
        self._connection = StateObject(wrappedValue: connection)
        self._controller = StateObject(wrappedValue: controller)
        
        self.dataStore = dataStore
        self.syncManager = syncManager
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Main content area
                TabView(selection: $selectedView) {
                    DashboardView(
                        connection: connection,
                        controller: controller,
                        logger: logger,
                        syncManager: syncManager,
                        databricksConfig: syncManager.databricksClient.config
                    )
                    .tag(AppView.dashboard)
                    
                    DetailsView(
                        controller: controller,
                        logger: logger,
                        connection: connection
                    )
                    .tag(AppView.details)
                    
                    DatabricksSettingsView(
                        syncManager: syncManager,
                        networkMonitor: syncManager.networkMonitor,
                        obd2Controller: controller
                    )
                    .tag(AppView.settings)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom bottom navigation
                ViewSelectorView(selectedView: $selectedView)
            }
        }
    }
}

