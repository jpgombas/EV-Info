import Foundation
import CoreData

/// Manages local persistence of vehicle data using CoreData
class DataStore: ObservableObject {
    
    // MARK: - Published Properties
    @Published var recentDataPoints: [VehicleDataPoint] = []
    
    // MARK: - Core Data Stack
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    init() {
        // Initialize Core Data stack
        persistentContainer = NSPersistentContainer(name: "VehicleData")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        
        // Load recent data points
        loadRecentDataPoints()
    }
    
    // MARK: - CRUD Operations
    
    /// Save a new data point
    func saveDataPoint(_ dataPoint: VehicleDataPoint) {
        let entity = VehicleDataEntity(context: context)
        entity.id = dataPoint.id
        entity.timestamp = dataPoint.timestamp
        entity.soc = dataPoint.soc ?? 0
        entity.isCharging = dataPoint.isCharging ?? false
        entity.speedKmh = Int16(dataPoint.speedKmh ?? 0)
        entity.currentAmps = dataPoint.currentAmps ?? 0
        entity.voltageVolts = dataPoint.voltageVolts ?? 0
        entity.ambientTempF = dataPoint.ambientTempF ?? 0
        
        if let distanceMiles = dataPoint.distanceMi {
            entity.distanceKm = distanceMiles * 1.60934
        }
        entity.syncedToDatabricks = false
        
        saveContext()
        loadRecentDataPoints()
    }
    
    /// Save multiple data points
    func saveDataPoints(_ dataPoints: [VehicleDataPoint]) {
        for dataPoint in dataPoints {
            saveDataPoint(dataPoint)
        }
    }
    
    /// Get all unsynced records
    func getUnsyncedRecords(limit: Int = 100) -> [VehicleDataPoint] {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "syncedToDatabricks == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        fetchRequest.fetchLimit = limit
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toVehicleDataPoint() }
        } catch {
            print("Error fetching unsynced records: \(error)")
            return []
        }
    }
    
    /// Get count of unsynced records
    func getUnsyncedRecordCount() -> Int {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "syncedToDatabricks == NO")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("Error counting unsynced records: \(error)")
            return 0
        }
    }
    
    /// Mark records as synced
    func markRecordsAsSynced(_ ids: [UUID]) {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        
        do {
            let entities = try context.fetch(fetchRequest)
            for entity in entities {
                entity.syncedToDatabricks = true
            }
            saveContext()
        } catch {
            print("Error marking records as synced: \(error)")
        }
    }
    
    /// Get recent data points (last 100)
    func loadRecentDataPoints() {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = 100
        
        do {
            let entities = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.recentDataPoints = entities.map { $0.toVehicleDataPoint() }
            }
        } catch {
            print("Error loading recent data points: \(error)")
        }
    }
    
    /// Get data points in date range
    func getDataPoints(from startDate: Date, to endDate: Date) -> [VehicleDataPoint] {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                            startDate as NSDate,
                                            endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toVehicleDataPoint() }
        } catch {
            print("Error fetching data points in range: \(error)")
            return []
        }
    }
    
    /// Delete old records (data retention)
    func deleteOldRecords(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp < %@ AND syncedToDatabricks == YES",
                                            cutoffDate as NSDate)
        
        do {
            let entities = try context.fetch(fetchRequest)
            for entity in entities {
                context.delete(entity)
            }
            saveContext()
            loadRecentDataPoints()
        } catch {
            print("Error deleting old records: \(error)")
        }
    }
    
    /// Export data as CSV
    func exportToCSV(dataPoints: [VehicleDataPoint]) -> String {
        var csv = VehicleDataPoint.csvHeader + "\n"
        csv += dataPoints.map { $0.toCSVRow() }.joined(separator: "\n")
        return csv
    }
    
    /// Get total record count
    func getTotalRecordCount() -> Int {
        let fetchRequest: NSFetchRequest<VehicleDataEntity> = VehicleDataEntity.fetchRequest()
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("Error counting total records: \(error)")
            return 0
        }
    }
    
    /// Delete all records (use with caution)
    func deleteAllRecords() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VehicleDataEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            loadRecentDataPoints()
        } catch {
            print("Error deleting all records: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}

// MARK: - Core Data Entity Extension

extension VehicleDataEntity {
    func toVehicleDataPoint() -> VehicleDataPoint {
        let dataPointID = id ?? UUID()
        var dataPoint = VehicleDataPoint(id: dataPointID, timestamp: timestamp ?? Date())
        dataPoint.soc = soc
        dataPoint.isCharging = isCharging
        dataPoint.speedKmh = Int(speedKmh)
        dataPoint.currentAmps = currentAmps
        dataPoint.voltageVolts = voltageVolts
        dataPoint.ambientTempF = ambientTempF
        dataPoint.distanceMi = distanceKm * 0.621371
        dataPoint.syncedToDatabricks = syncedToDatabricks
        
        return dataPoint
    }
}
