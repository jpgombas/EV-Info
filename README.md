# EV Info

An iOS app that connects to electric vehicles via Bluetooth OBD2, displays real-time telemetry on a live dashboard, and syncs collected data to Databricks for long-term analytics.

Built with SwiftUI, CoreBluetooth, and CoreData. Targets iOS 18.1+.

---

## What It Does

EV Info reads vehicle data from an ELM327-compatible OBD2 Bluetooth adapter (tested with VEEPEAK devices), displays it in real time, stores it locally, and uploads it to Databricks in configurable batches.

**Metrics tracked:**

| Metric             | Source ECU   | OBD2 PID  | Unit   |
|--------------------|--------------|-----------|--------|
| Battery Level      | BMS (7E4)    | 0x8334    | %      |
| Vehicle Speed      | Powertrain (7E0) | 0x010D | mph    |
| Battery Current    | Transmission (7E1) | 0x2414 | A      |
| Battery Voltage    | Transmission (7E1) | 0x2885 | V      |
| Power              | Calculated   | --        | kW     |
| Efficiency         | Calculated   | --        | mi/kWh |
| Distance Traveled  | Powertrain (7E0) | 0x0131 | mi     |
| Ambient Temp       | Powertrain (7E0) | 0x0046 | F      |

Power is derived from current x voltage. Efficiency is speed / power, clamped to a 0-20 range.

---

## App Structure

The app has three tabs:

**Dashboard** -- Live vehicle metrics in a card grid, BLE connection controls, sync status, and a toolbar button to open an embedded Databricks dashboard via WKWebView. The screen stays awake while this tab is active.

**Details** -- Scrollable debug log with a level picker (Verbose, Info, Success, Warning, Error, Data). Useful during development and for diagnosing OBD2 communication issues.

**Settings** -- Databricks connection configuration, upload method selection, sync controls (auto-sync interval, WiFi-only, batch size), OBD2 polling rate, and test buttons for verifying connectivity.

---

## Project Layout

```
EV Info/
  EV_InfoApp.swift                    App entry point, dependency wiring
  Models/
    VehicleData.swift                 Live telemetry state
    VehicleDataPoint.swift            Persistable data point (Codable)
    LogLevel.swift                    Log severity enum
  Views/
    ContentView.swift                 Tab container
    DashboardView.swift               Live metrics + embedded Databricks dashboard
    VehicleDataView.swift             Metric card grid
    DetailsView.swift                 Debug log viewer
    DatabricksSettingsView.swift      Configuration form
    ConnectionStatusView.swift        BLE status badge
    ConnectionControlsView.swift      Connect/disconnect buttons
    ViewSelectorView.swift            Tab bar
  Services/
    BLEConnection.swift               CoreBluetooth BLE wrapper
    OBD2Controller.swift              Command sequencing and data collection
    OBD2Parser.swift                  Hex response parsing and unit conversion
    DatabricksClient.swift            REST API client + Keychain helper
    SyncManager.swift                 Batch sync orchestration + NetworkMonitor
    DataStore.swift                   CoreData persistence layer
    Logger.swift                      In-memory debug log
    AppSecrets.swift                  Build-time secret access via Bundle
  Secrets.xcconfig                    Actual credentials (git-ignored)
  Secrets.xcconfig.template           Credential placeholder template
  Assets.xcassets/
  Preview Content/
    VehicleData.xcdatamodeld/         CoreData schema
EV-Info-Info.plist                    App configuration with $(VAR) references
.gitignore
```

---

## How It Works

### Connection and Data Collection

1. User taps Connect. `BLEConnection` scans for peripherals whose name contains "VEEPEAK", "OBD", or "ELM".
2. On discovery, it auto-connects and discovers the notify + write characteristics.
3. `OBD2Controller` sends an initialization sequence: `ATZ`, `ATD`, `ATE0`, `ATS0`, `ATAL`, `ATSP6`.
4. A polling timer fires every 0.8 seconds (configurable in Settings from 0.5-2.0s). Each cycle sends 9 commands across three ECUs (powertrain 7E0, transmission 7E1, BMS 7E4).
5. `OBD2Parser` extracts hex values from responses and applies manufacturer-specific formulas.
6. `VehicleData` updates on the main thread, driving the SwiftUI dashboard.
7. `OBD2Controller` periodically saves `VehicleDataPoint` records to CoreData via `DataStore`.

### Data Sync to Databricks

1. Unsynced records accumulate in CoreData with `syncedToDatabricks = false`.
2. `SyncManager` auto-syncs every 5 minutes (when enabled) or on manual trigger.
3. Records are fetched in batches (default 100, configurable 10-1000).
4. Uploaded via one of three methods:
   - **CSV** -- `PUT /api/2.0/fs/files/{volumePath}/vehicle_data_{timestamp}.csv`
   - **JSON** -- `POST /api/2.0/fs/files/{volumePath}/vehicle_data_{timestamp}.json`
   - **SQL Warehouse** -- `POST /api/2.0/sql/statements` with INSERT statement
5. On success, records are marked synced and the next batch starts after a 2-second delay.
6. On failure, retries up to 3 times with exponential backoff.
7. WiFi-only mode is available to avoid cellular data usage.

### Embedded Dashboard

The toolbar chart button on the Dashboard tab opens a `WKWebView` that loads a published Databricks dashboard. The web view handles OAuth/SSO redirects and persists the login session between app launches.

---

## Setup

### Prerequisites

- Xcode 16.1+
- iOS 18.1+ device (BLE does not work in the simulator)
- ELM327-compatible Bluetooth OBD2 adapter (VEEPEAK recommended)
- Databricks workspace with a Personal Access Token

### Configuration

1. Copy the secrets template:

```sh
cp "EV Info/Secrets.xcconfig.template" "EV Info/Secrets.xcconfig"
```

2. Edit `EV Info/Secrets.xcconfig` and fill in your values:

```
SLASH = /

DATABRICKS_WORKSPACE_URL = https:$(SLASH)/your-workspace.cloud.databricks.com
DATABRICKS_ACCESS_TOKEN = dapi_your_token_here
DATABRICKS_VOLUME_PATH = $(SLASH)/Volumes$(SLASH)/catalog$(SLASH)/schema$(SLASH)/volume
DATABRICKS_OAUTH_CLIENT_ID = your-client-id
DATABRICKS_OAUTH_CLIENT_SECRET = your-client-secret
DATABRICKS_DASHBOARD_ID = your-dashboard-id
DATABRICKS_WORKSPACE_ID = your-workspace-id
```

The `SLASH` variable is required because `//` is treated as a comment in xcconfig files.

3. Open `EV Info.xcodeproj` in Xcode and build.

The xcconfig values are injected into `Info.plist` at build time and read by `AppSecrets.swift` via `Bundle.main`. Settings entered in the app's Settings tab override these defaults at runtime (stored in UserDefaults and Keychain).

### Secrets Management

`Secrets.xcconfig` is listed in `.gitignore` and will never be committed. Only the `.template` file is tracked. The access token is stored in the iOS Keychain at runtime via the `DatabricksKeychain` helper.

---

## Data Schema

### CoreData Entity (local storage)

| Attribute          | Type     |
|--------------------|----------|
| id                 | UUID     |
| timestamp          | Date     |
| soc                | Double   |
| speedKmh           | Int16    |
| currentAmps        | Double   |
| voltageVolts       | Double   |
| distanceKm         | Double   |
| ambientTempF       | Double   |
| syncedToDatabricks | Boolean  |

### Databricks Table Columns

```
timestamp, soc, speed_kmh, current_amps, voltage_volts, distance_mi, ambient_temp_f
```

Distance is converted from km to miles before upload.

---

## OBD2 Protocol Details

The app uses ISO 15765-4 CAN (11-bit ID, 500 kbaud) set via `ATSP6`. Commands are sent sequentially with a 2.5-second timeout per response.

**Initialization sequence:** ATZ, ATD, ATE0, ATS0, ATAL, ATSP6

**Polling cycle (9 commands):**

```
ATSH7E0          Set header to powertrain ECU
010D             Vehicle speed
0131             Distance traveled since codes cleared
220046           Ambient air temperature
ATSH7E1          Set header to transmission ECU
222414           HV battery current (signed, /20)
222885           HV battery voltage (/100)
ATSH7E4          Set header to BMS ECU
228334           State of charge (/255 * 100)
```

The non-standard PIDs (22xxxx) are manufacturer-specific. The parsing formulas in `OBD2Parser.swift` are calibrated for the specific EV this was developed against.

---

## License

Private project. Not currently licensed for distribution.
