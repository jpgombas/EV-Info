# CoreData Setup Instructions

## ⚠️ IMPORTANT - Required Manual Step

The Databricks integration code references a CoreData model that must be created in Xcode. Follow these steps:

## Step 1: Create the Data Model File

1. **Open your project in Xcode**
   - File → New → File...
   - Select "Data Model"
   - Name it: `VehicleData`
   - Make sure it's added to your EV Info target
   - Click Create

   This creates: `VehicleData.xcdatamodeld`

## Step 2: Add the Entity

1. **In the data model editor, click "Add Entity"**
2. **Name the entity: `VehicleDataEntity`**
3. **Add the following attributes:**

| Attribute Name | Type | Optional |
|---|---|---|
| id | UUID | ❌ No |
| timestamp | Date | ✅ Yes |
| soc | Double | ❌ No (default 0) |
| batteryCapacityKWh | Double | ❌ No (default 0) |
| batteryTempCelsius | Double | ❌ No (default 0) |
| batteryTempFahrenheit | Double | ❌ No (default 0) |
| isCharging | Boolean | ❌ No (default false) |
| speedKmh | Integer 16 | ❌ No (default 0) |
| currentAmps | Double | ❌ No (default 0) |
| voltageVolts | Double | ❌ No (default 0) |
| cabinACPowerWatts | Double | ❌ No (default 0) |
| cabinHeatPowerWatts | Double | ❌ No (default 0) |
| transmissionPosition | Integer 16 | ❌ No (default 0) |
| syncedToDatabricks | Boolean | ❌ No (default false) |

## Step 3: Add Indexes (Optional but Recommended)

1. **Select VehicleDataEntity**
2. **Go to Data Model Inspector (right panel)**
3. **Under Indexes section, add two indexes:**
   - Index 1: Include `timestamp` (for date range queries)
   - Index 2: Include `syncedToDatabricks` (for finding unsynced records)

This improves query performance.

## Step 4: Verify Class Name

1. **Select VehicleDataEntity**
2. **Go to Data Model Inspector**
3. **Ensure:**
   - Module: None (or your app module)
   - Class: VehicleDataEntity ✅
   - Codegen: Manual/None ✅

   The code already includes the CoreData definition, so set to Manual.

## Step 5: Build and Verify

1. **Build the project: ⌘B**
2. **If there are no errors, you're done!**
3. **If errors occur:**
   - Check attribute names match exactly
   - Verify types are correct (Integer 16, not Integer 32)
   - Ensure the entity is named `VehicleDataEntity`

## Visual Guide

Your data model should look like this when complete:

```
VehicleData.xcdatamodeld
└── VehicleDataEntity (Entity)
    ├── id: UUID
    ├── timestamp: Date (Optional)
    ├── soc: Double
    ├── batteryCapacityKWh: Double
    ├── batteryTempCelsius: Double
    ├── batteryTempFahrenheit: Double
    ├── isCharging: Boolean
    ├── speedKmh: Integer 16
    ├── currentAmps: Double
    ├── voltageVolts: Double
    ├── cabinACPowerWatts: Double
    ├── cabinHeatPowerWatts: Double
    ├── transmissionPosition: Integer 16
    └── syncedToDatabricks: Boolean
```

## Troubleshooting

### Build Error: "Cannot find type 'VehicleDataEntity'"
**Solution:**
- Make sure the .xcdatamodeld file was added to your target
- Verify the entity name is exactly `VehicleDataEntity`
- Try building again after creating the model

### Build Error: "Attribute type mismatch"
**Solution:**
- Check that Integer 16 was used (not Integer 32 or Int)
- Verify Double for floating point values
- Verify UUID for id field

### Build Error: "CoreData Stack Failed"
**Solution:**
- Delete app from simulator/device
- Clean build folder: ⌘Shift K
- Build again: ⌘B

### Data not persisting between app launches
**Solution:**
- Check that CoreData model matches VehicleDataEntity.swift
- Verify DataStore init is called
- Check device storage space

## What Happens Next

After creating the CoreData model:

1. **DataStore** will automatically create the database
2. **OBD2Controller** will save data points locally
3. **SyncManager** will upload to Databricks
4. Everything works seamlessly together

## Don't Forget

After creating the CoreData model:

1. ✅ Build the project (⌘B)
2. ✅ Run on simulator or device
3. ✅ Connect OBD2 device
4. ✅ Configure Databricks in Settings
5. ✅ Watch data flow to the cloud!

## Questions?

If you encounter issues:
1. Check that all attribute names match exactly
2. Verify types are correct
3. Make sure .xcdatamodeld file is in your target
4. Delete derived data and rebuild
5. Restart Xcode if needed

---

**Once this is done, your Databricks integration is complete!** 🎉
