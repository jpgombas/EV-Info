# Databricks Integration Guide for EV Info

## Overview
Your EV Info app now includes complete Databricks integration for cloud storage of vehicle telemetry data collected from your OBD2 BLE device. This guide explains the setup and usage.

## Components Added

### 1. **Data Models**
- `VehicleDataPoint.swift` - Enhanced data structure with Codable support for cloud sync
- `VehicleDataEntity.swift` - CoreData entity for local persistence

### 2. **Services**
- `DataStore.swift` - CoreData manager for local data persistence
- `DatabricksClient.swift` - REST API client for Databricks
- `SyncManager.swift` - Handles automatic/manual data synchronization
- `NetworkMonitor.swift` - Monitors network connectivity

### 3. **UI**
- `DatabricksSettingsView.swift` - Settings interface for Databricks configuration

## Setup Instructions

### Step 1: Configure Databricks Workspace
1. Go to your Databricks workspace
2. Create or identify your upload destination:
   - **CSV/JSON Method**: Create a Unity Catalog volume (e.g., `/Volumes/catalog/schema/my_volume`)
   - **SQL Warehouse Method**: Create a table and SQL warehouse endpoint

### Step 2: Generate Access Token
1. In Databricks, click your profile icon → User Settings
2. Navigate to Personal access tokens
3. Click "Generate new token"
4. Copy the token (you'll need this)

### Step 3: Configure in App
1. Open the app and tap the **Settings** tab
2. Enter your Databricks configuration:
   - **Workspace URL**: Your Databricks workspace URL (e.g., `https://adb-1234567890.cloud.databricks.com`)
   - **Access Token**: Your personal access token (keep this private and secure)
   - **Upload Method**: Choose one of:
     - CSV (recommended for most users)
     - JSON (for more detailed data)
     - SQL Warehouse (for direct database insertion)

3. For **CSV/JSON methods**:
   - **Volume Path**: Your Unity Catalog volume path in format `/Volumes/catalog/schema/volume` (e.g., `/Volumes/vehicle_data/telemetry/uploads`)

4. For **SQL Warehouse method**:
   - **Warehouse ID**: Your SQL warehouse endpoint ID
   - **Table Name**: Target table name

### Step 4: Test Connection
1. Tap "Test Connection"
2. Confirm the connection is successful
3. Tap "Save Configuration"

### Step 5: Configure Sync Settings
1. Toggle **Auto Sync Enabled** to automatically upload collected data
2. Toggle **WiFi Only** if you want to sync only on WiFi (recommended)
3. Adjust **Batch Size** (default 100 records per sync)

## Data Collection Flow

```
OBD2 Device
    ↓
BLEConnection (reads data)
    ↓
OBD2Parser (parses OBD responses)
    ↓
OBD2Controller (manages collection)
    ↓
VehicleDataPoint (structures data)
    ↓
DataStore (local persistence via CoreData)
    ↓
SyncManager (uploads to Databricks)
```

## Data Structure

Each data point contains:
- **timestamp** - Collection time
- **soc** - State of Charge (%)
- **batteryCapacityKWh** - Battery capacity
- **batteryTempCelsius/Fahrenheit** - Battery temperature
- **isCharging** - Charging status
- **speedKmh** - Vehicle speed
- **currentAmps** - Battery current
- **voltageVolts** - Battery voltage
- **cabinACPowerWatts** - AC power usage
- **cabinHeatPowerWatts** - Heat power usage
- **transmissionPosition** - Transmission gear/mode
- **syncedToDatabricks** - Sync status flag

## Auto Sync Behavior

When **Auto Sync** is enabled:
- Syncs automatically every 5 minutes
- Respects WiFi-only preference if enabled
- Uses exponential backoff for retries
- Marks synced records to avoid duplicates
- Continues with next batch if records remain

## Manual Sync

1. Go to Settings tab
2. Review pending records count
3. Tap "Sync Now" to manually upload data
4. Monitor sync status with progress indicator

## Local Storage

All collected data is stored locally using CoreData until successfully synced:
- Data persists between app sessions
- Last 100 data points displayed in Settings
- Old synced records are automatically cleaned up (default 30 days)
- Unsynced data is retained indefinitely

## Upload Methods

### CSV Method
- Stores data as CSV files in your Databricks volume
- Filename: `vehicle_data_YYYY-MM-DDTHH:MM:SS.csv`
- Recommended for most users
- Easy to query and process

### JSON Method
- Stores data as JSON files in your Databricks volume
- Filename: `vehicle_data_YYYY-MM-DDTHH:MM:SS.json`
- Preserves data types and nested structures
- Slightly more storage-intensive

### SQL Warehouse Method
- Directly inserts data into a Databricks table
- Requires SQL warehouse and properly structured table
- Best for real-time analytics
- Fastest query performance

## Database Schema (for SQL Warehouse)

Create this table in your Databricks SQL warehouse:

```sql
CREATE TABLE vehicle_data (
    timestamp TIMESTAMP,
    soc DOUBLE,
    battery_capacity_kwh DOUBLE,
    battery_temp_celsius DOUBLE,
    battery_temp_fahrenheit DOUBLE,
    is_charging BOOLEAN,
    speed_kmh INT,
    current_amps DOUBLE,
    voltage_volts DOUBLE,
    cabin_ac_power_watts DOUBLE,
    cabin_heat_power_watts DOUBLE,
    transmission_position INT
)
```

## Security

- **Access Token**: Stored securely in iOS Keychain
- **Configuration**: Encrypted in UserDefaults
- **No data stored in plaintext**: All sensitive data uses secure storage
- **TLS/HTTPS**: All Databricks API calls use encrypted connections

## Troubleshooting

### Connection Test Fails
- Verify workspace URL format (include https://)
- Check access token is valid and not expired
- Ensure token has necessary permissions
- Check network connectivity

### Data Not Syncing
- Confirm WiFi connection (if WiFi-only is enabled)
- Check pending records count in Settings
- Tap "Sync Now" to manually trigger
- Review error message in Settings
- Check if Databricks workspace is accessible

### No Data Collected
- Verify OBD2 device is connected (Dashboard tab)
- Check vehicle engine is running (for some data points)
- Monitor debug logs
- Ensure OBD2 commands are properly configured

### Storage Full
- Old synced records are automatically cleaned after 30 days
- Reduce batch size to sync more frequently
- Review total record count in Settings

## Performance Notes

- Data collection: ~1 record every 10 seconds per data point cycle
- Local storage: Each record ~500 bytes, minimal overhead
- Network: ~500 records = ~250KB per upload
- Battery impact: Minimal for local collection, normal for WiFi sync

## Future Enhancements

Consider implementing:
- Real-time data streaming to Databricks
- Delta Lake table format support
- Automated data quality checks
- Data retention policies
- Dashboard integration

## Support

For issues or questions:
1. Check the error message in Settings
2. Review Databricks workspace logs
3. Verify OBD2 device connection
4. Test with manual sync first
