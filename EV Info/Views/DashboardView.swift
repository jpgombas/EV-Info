//
//  DashboardView.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var connection: BLEConnection
    @ObservedObject var controller: OBD2Controller
    @ObservedObject var logger: Logger
    @ObservedObject var syncManager: SyncManager
    let databricksConfig: DatabricksClient.Config

    var body: some View {
        VStack(spacing: 20) {
            // Connection and Sync Status Row
            HStack(spacing: 12) {
                ConnectionStatusView(
                    connectionStatus: connection.connectionStatus,
                    isConnected: connection.isConnected
                )
                
                SyncStatusView(syncManager: syncManager)
            }
            
            VehicleDataView(vehicleData: controller.vehicleData)
            
            ConnectionControlsView(
                connection: connection,
                logger: logger
            )
            
            Spacer()
        }
        .padding()
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: DatabricksDashboardView(databricksConfig: databricksConfig)) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }
        }
        .onAppear {
            // Prevent screen from sleeping while on dashboard
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable screen sleep when leaving dashboard
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Databricks Dashboard View
struct DatabricksDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    let databricksConfig: DatabricksClient.Config
    let dashboardId = "REDACTED_DASHBOARD_ID"
    let workspaceId = "REDACTED_WORKSPACE_ID"
    
    var body: some View {
        ZStack {
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Failed to load dashboard")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        errorMessage = nil
                        isLoading = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                DatabricksEmbeddedWebView(
                    config: databricksConfig,
                    dashboardId: dashboardId,
                    workspaceId: workspaceId,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                .edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Loading Dashboard...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Dashboard")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Databricks Embedded WebView
import WebKit

struct DatabricksEmbeddedWebView: UIViewRepresentable {
    let config: DatabricksClient.Config
    let dashboardId: String
    let workspaceId: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Use persistent data store so login session persists between app launches
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.pageZoom = 1.25

        // Enable debugging
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load once
        guard webView.url == nil else { return }

        // Load the published dashboard URL directly — user authenticates via Databricks login
        let dashboardURL = URL(string: "\(config.workspaceURL)/dashboardsv3/\(dashboardId)/published?o=\(workspaceId)")!
        webView.load(URLRequest(url: dashboardURL))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        @Binding var errorMessage: String?
        
        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            self._isLoading = isLoading
            self._errorMessage = errorMessage
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigations including OAuth/SSO redirects
            decisionHandler(.allow)
        }

        // Handle new window requests (target="_blank" links, OAuth popups) by loading in the same webview
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil || !(navigationAction.targetFrame!.isMainFrame) {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
    
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @ObservedObject var syncManager: SyncManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: syncManager.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                    .foregroundColor(syncManager.isSyncing ? .blue : .green)
                    .font(.caption)
                Text("Sync")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                // Pending count
                Label {
                    Text("\(syncManager.pendingRecordCount)")
                        .font(.caption2)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                
                // Synced count
                Label {
                    Text("\(syncManager.totalSyncedRecords)")
                        .font(.caption2)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}
