import Foundation

struct VehicleData {
    var ambientTempF: Double = 0.0
    var speed: Double = 0
    var batteryCurrent: Double = 0.0
    var voltage: Double = 0.0
    var power: Double = 0.0
    var efficiency: Double = 0.0
    var stateOfCharge: Double = 0.0
    var longdistance: Double = 0.0
    var relativeDistance: Double = 0.0  // Distance from start/reset point
    
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
}
