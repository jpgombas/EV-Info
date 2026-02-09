import Foundation

/// Centralized access to secrets injected via Secrets.xcconfig → Info.plist.
/// Values are set at build time and read from the app bundle.
enum AppSecrets {
    static var databricksWorkspaceURL: String {
        Bundle.main.infoDictionary?["DATABRICKS_WORKSPACE_URL"] as? String ?? ""
    }

    static var databricksAccessToken: String {
        Bundle.main.infoDictionary?["DATABRICKS_ACCESS_TOKEN"] as? String ?? ""
    }

    static var databricksVolumePath: String {
        Bundle.main.infoDictionary?["DATABRICKS_VOLUME_PATH"] as? String ?? ""
    }

    static var oauthClientId: String {
        Bundle.main.infoDictionary?["DATABRICKS_OAUTH_CLIENT_ID"] as? String ?? ""
    }

    static var oauthClientSecret: String {
        Bundle.main.infoDictionary?["DATABRICKS_OAUTH_CLIENT_SECRET"] as? String ?? ""
    }

    static var databricksDashboardId: String {
        Bundle.main.infoDictionary?["DATABRICKS_DASHBOARD_ID"] as? String ?? ""
    }

    static var databricksWorkspaceId: String {
        Bundle.main.infoDictionary?["DATABRICKS_WORKSPACE_ID"] as? String ?? ""
    }
}
