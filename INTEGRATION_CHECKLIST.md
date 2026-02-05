# 🚀 Databricks Integration - Complete Checklist

## Pre-Integration Setup
- [ ] You have Xcode open with the EV Info project
- [ ] You can build and run the existing app
- [ ] You have access to a Databricks workspace
- [ ] You've generated a Databricks personal access token

## Code Integration Complete ✅
- [x] Created VehicleDataPoint.swift (data model)
- [x] Created VehicleDataEntity.swift (CoreData definition)
- [x] Created DataStore.swift (local persistence)
- [x] Created DatabricksClient.swift (cloud API)
- [x] Created SyncManager.swift (synchronization)
- [x] Created DatabricksSettingsView.swift (UI)
- [x] Modified EV_InfoApp.swift (initialization)
- [x] Modified ContentView.swift (UI integration)
- [x] Modified OBD2Controller.swift (data collection)

## Required Manual Steps (Do These Now)
- [ ] **Create CoreData Model** (CRITICAL)
  - [ ] File → New → Data Model
  - [ ] Name: `VehicleData`
  - [ ] Add `VehicleDataEntity` with all attributes
  - [ ] Follow [COREDATA_SETUP.md](COREDATA_SETUP.md)
  - [ ] Build project (⌘B) - should compile

## Build and Test Locally
- [ ] Build project (⌘B) - zero errors
- [ ] Run on simulator (⌘R)
- [ ] App launches without crashing
- [ ] Dashboard tab shows "Disconnected"
- [ ] New "Settings" tab appears in bottom nav
- [ ] Settings tab shows empty form

## Connect OBD2 Device
- [ ] OBD2 adapter is connected to vehicle
- [ ] Vehicle is running (engine on)
- [ ] iPhone Bluetooth is on
- [ ] Tap Dashboard tab
- [ ] Tap "Connect" or "Scan" button
- [ ] Device connects (status shows "Connected")
- [ ] Data appears (speed, voltage, current showing values)
- [ ] Go to Settings tab
- [ ] Verify "Pending Records" counter is increasing

## Prepare Databricks Workspace
- [ ] Have workspace URL: https://adb-______.cloud.databricks.com
- [ ] Have generated personal access token: dapi____...
- [ ] Choose upload method:
  - [ ] **CSV**: Create volume path `/Volumes/catalog/schema/volume`
  - [ ] **JSON**: Create volume path `/Volumes/catalog/schema/volume`
  - [ ] **SQL**: Create SQL warehouse and table

### For CSV/JSON Methods
```sql
-- Databricks SQL - Run this to create the volume
CREATE VOLUME IF NOT EXISTS /Volumes/your_catalog/your_schema/ev_data;
```

### For SQL Warehouse Method
```sql
-- Databricks SQL - Run this to create the table
CREATE TABLE IF NOT EXISTS vehicle_telemetry (
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
);
```

## Configure App Settings
1. [ ] Tap **Settings** tab in EV Info
2. [ ] Enter **Workspace URL**
   - Example: `https://adb-1234567890.cloud.databricks.com`
3. [ ] Enter **Access Token**
   - Example: `dapi123456789abcdef...`
4. [ ] Select **Upload Method**
   - [ ] CSV (easiest to start)
   - [ ] JSON (more data types)
   - [ ] SQL Warehouse (real-time analytics)
5. [ ] Enter upload destination:
   - If CSV/JSON: Enter **Volume Path**
     - Example: `/Volumes/catalog/schema/ev_data`
   - If SQL: Enter **Warehouse ID** and **Table Name**
6. [ ] Tap **Test Connection**
   - [ ] Should show "✓ Connection successful!"
   - [ ] If it fails, check:
     - [ ] URL has `https://`
     - [ ] Token is not expired
     - [ ] Network is connected
7. [ ] Tap **Save Configuration**
8. [ ] Settings should show no errors

## Enable Auto-Sync
- [ ] Toggle **Auto Sync Enabled** to ON
- [ ] Toggle **WiFi Only** to ON (optional, recommended)
- [ ] Keep **Batch Size** at 100 (or adjust as needed)

## Verify Data Flow
1. [ ] Keep Settings tab open
2. [ ] Verify "Pending Records" is increasing (every 10 seconds, ~1 record)
3. [ ] Wait 5 minutes (auto-sync interval)
4. [ ] Watch "Last Sync" timestamp update
5. [ ] Go to Databricks workspace
6. [ ] Check your volume or table for new data
7. [ ] Verify files are being created or rows are being inserted

## Manual Sync Test (Optional)
- [ ] Go to Settings tab
- [ ] Verify Pending Records > 0
- [ ] Tap **Sync Now**
- [ ] Watch progress indicator
- [ ] See "Total Synced" counter increase
- [ ] Check Databricks for new data

## Verify in Databricks
- [ ] Log into your Databricks workspace
- [ ] Navigate to your volume/table
- [ ] Run query to see data:

For CSV/JSON in volume:
```sql
SELECT * FROM read_files('/Volumes/your_catalog/your_schema/ev_data')
LIMIT 10;
```

For SQL table:
```sql
SELECT * FROM vehicle_telemetry
ORDER BY timestamp DESC
LIMIT 10;
```

- [ ] Confirm data matches app collection times
- [ ] Verify all fields are populated correctly

## Post-Integration Testing
- [ ] Disconnect OBD2, verify sync stops
- [ ] Reconnect OBD2, verify data collection resumes
- [ ] Force quit app, relaunch - verify pending data still uploads
- [ ] Disable WiFi, verify WiFi-only setting is respected
- [ ] Enable WiFi, verify sync resumes
- [ ] Clear app from device, reinstall - verify settings saved securely

## Optional: Build a Dashboard
- [ ] In Databricks, create SQL queries:
  - [ ] Query 1: Last 24 hours of data
  - [ ] Query 2: Average metrics by hour
  - [ ] Query 3: Battery health trends
- [ ] Create visualizations (charts, tables)
- [ ] Set up dashboard for monitoring

## Documentation Review
- [ ] Read [QUICKSTART.md](QUICKSTART.md) - Quick reference
- [ ] Read [DATABRICKS_INTEGRATION.md](DATABRICKS_INTEGRATION.md) - Full guide
- [ ] Read [INTEGRATION_SUMMARY.md](INTEGRATION_SUMMARY.md) - Technical details
- [ ] Read [COREDATA_SETUP.md](COREDATA_SETUP.md) - If CoreData issues

## Production Readiness
- [ ] Security review:
  - [ ] Tokens never logged or displayed
  - [ ] Data encrypted in transit (HTTPS)
  - [ ] Local data encrypted by iOS
  - [ ] Keychain used for token storage
- [ ] Performance review:
  - [ ] No memory leaks detected
  - [ ] Minimal battery impact
  - [ ] Network calls only on WiFi (if enabled)
- [ ] Error handling:
  - [ ] Failed syncs show errors
  - [ ] Network disconnection handled gracefully
  - [ ] Invalid config prevents upload
- [ ] Data quality:
  - [ ] All fields collected correctly
  - [ ] Timestamps are accurate
  - [ ] No data corruption in transit

## Monitoring Ongoing
- [ ] Check app Settings regularly:
  - [ ] Pending Records should eventually reach 0
  - [ ] Total Synced should increase over time
  - [ ] Last Sync timestamp should be recent
- [ ] Monitor Databricks:
  - [ ] New files appear in volume
  - [ ] Table rows increase
  - [ ] No error patterns in data
- [ ] Watch for issues:
  - [ ] Network failures
  - [ ] Disk space issues
  - [ ] Token expiration

## Troubleshooting Quick Reference

| Problem | Check | Fix |
|---------|-------|-----|
| CoreData error on build | Data model created? | Follow COREDATA_SETUP.md |
| Settings tab missing | ContentView updated? | Verify AppView enum has .settings |
| Connection test fails | Token expired? | Generate new token in Databricks |
| No pending records | OBD2 connected? | Connect device and wait 10 seconds |
| Sync doesn't run | WiFi connected? | Toggle WiFi or disable WiFi-only |
| Data in app but not cloud | Workspace URL correct? | Test connection and verify upload |

## Final Verification Checklist
- [ ] ✅ All Swift files created
- [ ] ✅ All Swift files modified
- [ ] ✅ CoreData model created
- [ ] ✅ Project builds without errors
- [ ] ✅ App runs without crashes
- [ ] ✅ Settings tab accessible
- [ ] ✅ OBD2 device connects
- [ ] ✅ Data collection working
- [ ] ✅ Databricks configured
- [ ] ✅ Connection test passes
- [ ] ✅ Manual sync works
- [ ] ✅ Auto-sync runs
- [ ] ✅ Data appears in Databricks
- [ ] ✅ All documentation read

## You're Done! 🎉

Once all items are checked:
- Your EV Info app collects vehicle data locally
- Automatically syncs to Databricks every 5 minutes
- Data persists if app crashes
- Network-aware sync respects connectivity
- Secure credential storage
- Beautiful UI for configuration
- Ready for analytics and dashboards

## Next Adventures 🚀
- Build Databricks dashboards
- Create alerts on vehicle health metrics
- Track charging patterns
- Monitor battery degradation
- Share data with mechanics
- Integrate with other tools (Slack, email, etc.)

---

**Congratulations!** You now have enterprise-grade vehicle telemetry in the cloud. 🚗☁️
