import Foundation

struct VehicleData {
    var ambientTempF: Double = 0.0
    var speed: Double = 0
    var batteryCurrent: Double = 0.0
    var voltage: Double = 0.0
    var power: Double = 0.0
    var efficiency: Double = 0.0
    var stateOfCharge: Double = 0.0
    var distance: Double = 0.0
    var longdistance: Double = 0.0
    
    mutating func updatePower() {
        power = batteryCurrent * voltage / 1000.0
    }
    
    mutating func updateEfficiency() {
        let eff = speed / power
        efficiency = (eff < 0 || eff > 20) ? -1 : abs(eff)
    }
    
    mutating func updatePowerAndEfficiency() {
        updatePower()
        updateEfficiency()
    }
    
    mutating func updateDistance(timeInterval: TimeInterval) {
        // Convert speed from mph to miles per second, then multiply by time interval
        let milesPerSecond = speed / 3600.0
        distance += milesPerSecond * timeInterval
    }
}

