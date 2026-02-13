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

    // New efficiency-related fields
    var socHD: Double = 0.0               // % raw high-resolution SOC
    var batteryAvgTempC: Double = 0.0
    var batteryMaxTempC: Double = 0.0
    var batteryMinTempC: Double = 0.0
    var batteryCoolantTempC: Double = 0.0
    var hvacMeasuredPowerW: Double = 0.0
    var hvacCommandedPowerW: Double = 0.0
    var acCompressorOn: Bool = false
    var batteryCapacityAh: Double = 0.0
    var batteryResistanceMOhm: Double = 0.0

    // Computed: drivetrain power excluding HVAC
    var drivetrainPowerKW: Double {
        power - (hvacMeasuredPowerW / 1000.0)
    }

    // Computed: battery temperature spread (thermal gradient)
    var batteryTempSpread: Double {
        batteryMaxTempC - batteryMinTempC
    }

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
