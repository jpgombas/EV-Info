//
//  VehicleData.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import Foundation

struct VehicleData {
    var speed: Double = 0
    var batteryCurrent: Double = 0.0
    var voltage: Double = 0.0
    var power: Double = 0.0
    var efficiency: Double = 0.0
    var stateOfCharge: Double = 0.0
    
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
