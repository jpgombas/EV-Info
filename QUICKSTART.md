# Quick Start Guide - Databricks Integration

## 1. Before You Start
- ✅ Have your Databricks workspace URL
- ✅ Have generated an access token in Databricks
- ✅ Know your upload destination (volume path or SQL table)

## 2. First-Time Setup (5 minutes)

### Launch the App
1. Open EV Info in Xcode
2. Build and run on your device
3. Connect to your OBD2 device via the Dashboard tab

### Configure Databricks
1. Tap **Settings** tab (new)
2. Enter your **Workspace URL**
3. Enter your **Access Token**
4. Select **Upload Method** (CSV recommended for beginners)
5. Enter **Volume Path** (for CSV/JSON) or **SQL credentials**
6. Tap **Test Connection** - should succeed
7. Tap **Save Configuration**

### Enable Auto-Sync
1. Toggle **Auto Sync Enabled** ON
2. Toggle **WiFi Only** ON (optional but recommended)
3. Data will sync automatically every 5 minutes when connected

## 3. Verify It Works

### Check Local Collection
- Go to Dashboard
- Verify vehicle data displays (speed, voltage, current)
- Go to Settings
- Check **Pending Records** counter - should increase

### Check Cloud Sync
- Stay on Settings tab
- Watch for **Last Sync** timestamp to update
- Or manually tap **Sync Now**
- Go to Databricks and verify files in your volume

## 4. Monitor Ongoing

### In the App
- **Pending Records**: How many are waiting to upload
- **Total Synced**: Lifetime upload count
- **Last Sync**: When was the last successful upload
- **Network**: Shows WiFi/Cellular/Offline status
- **Last Error**: If sync fails, see the error here

### In Databricks
- Check your volume for new CSV/JSON files
- Query your table if using SQL Warehouse method
- Use Delta Live Tables for real-time analytics

## 5. Troubleshooting Quick Fixes

| Issue | Fix |
|-------|-----|
| Connection test fails | Check URL format, token validity, network |
| No pending records | OBD2 device might not be collecting data |
| Sync not running | Check WiFi is connected (if WiFi-only enabled) |
| Data not appearing in Databricks | Check volume path or table exists |
| App crashes | Make sure CoreData schema is created in Xcode |

## 6. Building a Dashboard (Optional)

After data is in Databricks, you can:

### For CSV Files in Volume
```sql
SELECT * 
FROM read_files('/Volumes/your_catalog/your_schema/your_volume')
WHERE timestamp >= current_timestamp() - INTERVAL 1 DAY
```

### For SQL Table
```sql
SELECT 
  DATE(timestamp) as date,
  COUNT(*) as records,
  AVG(soc) as avg_soc,
  AVG(speed_kmh) as avg_speed,
  AVG(voltage_volts) as avg_voltage
FROM vehicle_telemetry
GROUP BY DATE(timestamp)
```

## 7. Common Configurations

### Home Lab / Testing
```
Workspace URL: https://adb-1234567890.cloud.databricks.com
Volume Path: /Volumes/main/default/test_data
Auto Sync: Disabled (manual sync via button)
```

### Production / Regular Use
```
Workspace URL: https://adb-1234567890.cloud.databricks.com
Volume Path: /Volumes/ev_telemetry/raw/vehicle_data
Auto Sync: Enabled
WiFi Only: Enabled
Batch Size: 100-500 records
```

### Real-Time Analytics
```
Workspace URL: https://adb-1234567890.cloud.databricks.com
SQL Warehouse: your-warehouse-id
Table: vehicle_telemetry_live
Auto Sync: Enabled
Batch Size: 50-100 (faster uploads)
```

## 8. Data Dictionary

Each synced record contains:

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| timestamp | DateTime | 2025-02-04T14:30:45Z | Collection time |
| soc | Double | 75.5 | State of charge % |
| battery_capacity_kwh | Double | 85.0 | Battery capacity |
| battery_temp_celsius | Double | 25.3 | Battery temperature |
| battery_temp_fahrenheit | Double | 77.5 | Battery temperature |
| is_charging | Boolean | true | Charging status |
| speed_kmh | Integer | 65 | Vehicle speed |
| current_amps | Double | 12.5 | Battery current |
| voltage_volts | Double | 396.2 | Battery voltage |
| cabin_ac_power_watts | Double | 2000.0 | AC power usage |
| cabin_heat_power_watts | Double | 500.0 | Heat power usage |
| transmission_position | Integer | 3 | Gear/mode (1=P, 2=R, 3=N, 4=D) |

## 9. Best Practices

✅ **Do:**
- Test connection before enabling auto-sync
- Start with manual sync to verify
- Check Databricks logs if sync fails
- Use WiFi-only for initial setup
- Monitor pending records regularly

❌ **Don't:**
- Share your access token
- Use test tokens in production
- Expect data before OBD2 device connects
- Change volumes mid-sync
- Manually modify local data files

## 10. Getting Help

### Check These First
1. Is network connected? (Check Settings network indicator)
2. Is OBD2 device connected? (Check Dashboard)
3. Are credentials correct? (Tap Test Connection)
4. Check Last Error message in Settings

### In Databricks
- Look at API audit logs
- Check volume/table exists
- Verify permissions on access token
- Check SQL warehouse is running

### Useful Links
- [DATABRICKS_INTEGRATION.md](DATABRICKS_INTEGRATION.md) - Full documentation
- [INTEGRATION_SUMMARY.md](INTEGRATION_SUMMARY.md) - Technical details
- Databricks docs: https://docs.databricks.com

---

**That's it!** You now have enterprise-grade cloud storage for your EV telemetry data. 🚗☁️
