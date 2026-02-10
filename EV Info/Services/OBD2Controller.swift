//
//  OBD2Controller.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import Foundation
import Combine

class OBD2Controller: ObservableObject {
    private let connection: BLEConnection
    private let parser: OBD2Parser
    private let logger: Logger
    private let dataStore: DataStore?
    
    @Published var vehicleData = VehicleData()
    
    // Timers and state
    private var dataTimer: Timer?
    private var initResponseTimer: Timer?
    private var currentCommandIndex = 0
    private var isWaitingForResponse = false
    private var responseBuffer = ""
    private var initCommandIndex = 0
    private var isInitializing = false
    private var initialLongDistance: Double?  // Track starting distance for relative calculation
    
    @Published var dataTimerDuration = 0.8 {
        didSet {
            if dataTimer != nil {
                restartDataTimer()
            }
        }
    }

    @Published var fastPollingEnabled = false {
        didSet {
            if dataTimer != nil {
                currentCommandIndex = 0
                needsHeaderRestore = false
                if fastPollingEnabled {
                    // Start with a full sweep to get initial readings
                    isDoingFullSweep = true
                    fullSweepCommandIndex = 0
                    lastFullSweepTime = Date()
                } else {
                    isDoingFullSweep = false
                    lastFullSweepTime = Date()
                }
                restartDataTimer()
                logger.log(.info, fastPollingEnabled ? "Fast polling enabled (current only)" : "Fast polling disabled (normal mode)")
            }
        }
    }

    // Fast polling state
    private let fastCommand = "222414"  // Current PID (header already set to 7E1 after sweep)
    private var lastFullSweepTime = Date()
    private let fullSweepInterval: TimeInterval = 300  // 5 minutes
    private var isDoingFullSweep = false
    private var fullSweepCommandIndex = 0
    private var needsHeaderRestore = false  // Send ATSH7E1 once after full sweep

    // Data collection
    private var currentDataPoint = VehicleDataPoint(timestamp: Date())
    
    // Commands
    private let initCommands = ["ATZ", "ATD", "ATE0", "ATS0", "ATAL", "ATSP6"]
    private let fetchCommands = [
        "ATSH7E0",  // (ECU 0x7E0)
        "010D",     // Vehicle speed
        "0131",    // Distance traveled
        "220046",  // Ambient air temperature
        "ATSH7E1", //(ECU 0x7E1)
        "222414",   // Current
        "222885",   // Voltage
        "ATSH7E4",  // Switch header to BMS
        "228334"    // State of charge (BMS ECU)
    ]
    
    init(connection: BLEConnection, parser: OBD2Parser, logger: Logger, dataStore: DataStore? = nil) {
        self.connection = connection
        self.parser = parser
        self.logger = logger
        self.dataStore = dataStore
        
        setupConnectionCallbacks()
    }
    
    private func setupConnectionCallbacks() {
        connection.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
        
        connection.onConnectionStateChanged = { [weak self] isConnected in
            if isConnected {
                self?.startInitSequence()
            } else {
                self?.stopAllTimers()
            }
        }
    }
    
    private func startInitSequence() {
        logger.log(.info, "Starting OBD2 initialization (\(initCommands.count) commands)")
        initCommandIndex = 0
        isInitializing = true
        sendNextInitCommand()
    }
    
    private func sendNextInitCommand() {
        guard initCommandIndex < initCommands.count, isInitializing else { return }
        
        let command = initCommands[initCommandIndex]
        logger.log(.verbose, "Init (\(initCommandIndex + 1)/\(initCommands.count)): \(command)")
        
        let data = (command + "\r").data(using: .utf8)!
        connection.writeData(data)
        
        initResponseTimer?.invalidate()
        initResponseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.logger.log(.warning, "Init timeout: \(command)")
            self?.continueInitSequence()
        }
    }
    
    private func continueInitSequence() {
        initResponseTimer?.invalidate()
        initCommandIndex += 1

        if initCommandIndex >= initCommands.count {
            isInitializing = false
            logger.log(.success, "Initialization complete - starting data fetch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startDataFetching()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendNextInitCommand()
            }
        }
    }
    
    private func startDataFetching() {
        logger.log(.info, "Starting periodic data fetching\(fastPollingEnabled ? " (fast mode)" : "")")

        dataTimer?.invalidate()
        currentCommandIndex = 0
        isWaitingForResponse = false
        fullSweepCommandIndex = 0
        needsHeaderRestore = false

        if fastPollingEnabled {
            // Start with a full sweep to get initial readings for all values
            isDoingFullSweep = true
            lastFullSweepTime = Date()
            logger.log(.info, "Starting initial full sweep before fast polling")
        } else {
            isDoingFullSweep = false
            lastFullSweepTime = Date()
        }
        
        dataTimer = Timer.scheduledTimer(withTimeInterval: dataTimerDuration, repeats: true) { [weak self] timer in
            self?.sendNextDataCommand()
        }
    }
    
    private func restartDataTimer() {
        guard connection.isConnected, dataTimer != nil else { return }
        
        logger.log(.info, "Restarting data timer with new duration: \(dataTimerDuration)s")
        dataTimer?.invalidate()
        
        dataTimer = Timer.scheduledTimer(withTimeInterval: dataTimerDuration, repeats: true) { [weak self] timer in
            self?.sendNextDataCommand()
        }
    }
    
    private func sendNextDataCommand() {
        guard connection.isConnected else {
            logger.log(.warning, "Data timer stopped - not connected")
            dataTimer?.invalidate()
            return
        }

        if isWaitingForResponse {
            logger.log(.verbose, "Skipping cycle - waiting for response")
            return
        }

        let command: String

        if fastPollingEnabled {
            if isDoingFullSweep {
                // During a full sweep, cycle through all fetchCommands
                command = fetchCommands[fullSweepCommandIndex]
                fullSweepCommandIndex += 1
                if fullSweepCommandIndex >= fetchCommands.count {
                    // Full sweep complete — need to restore header to 7E1 for fast current polling
                    fullSweepCommandIndex = 0
                    isDoingFullSweep = false
                    needsHeaderRestore = true
                    lastFullSweepTime = Date()
                    logger.log(.info, "Full sweep complete, restoring header for fast polling")
                }
            } else if needsHeaderRestore {
                // Restore CAN header to 7E1 (battery/inverter) after full sweep
                command = "ATSH7E1"
                needsHeaderRestore = false
                logger.log(.verbose, "Restoring header to 7E1 for fast polling")
            } else if Date().timeIntervalSince(lastFullSweepTime) >= fullSweepInterval {
                // Time for a full sweep
                isDoingFullSweep = true
                fullSweepCommandIndex = 0
                command = fetchCommands[fullSweepCommandIndex]
                fullSweepCommandIndex += 1
                logger.log(.info, "Starting full sweep (5 min interval)")
            } else {
                // Fast mode: just send the current PID (header already set to 7E1)
                command = fastCommand
            }
        } else {
            // Normal mode: round-robin through all commands
            command = fetchCommands[currentCommandIndex]
            currentCommandIndex = (currentCommandIndex + 1) % fetchCommands.count
        }

        let data = (command + "\r").data(using: .utf8)!

        logger.log(.verbose, "Sending: \(command)")
        connection.writeData(data)
        isWaitingForResponse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }
            if self.isWaitingForResponse {
                self.logger.log(.warning, "Response timeout: \(command)")
                self.isWaitingForResponse = false
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        if logger.logLevel == .verbose {
            logger.log(.data, "Raw: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        guard let chunk = String(data: data, encoding: .utf8) else {
            logger.log(.error, "Could not decode data")
            return
        }
        
        // Handle init responses
        if isInitializing {
            responseBuffer.append(chunk)
            if responseBuffer.contains(">") {
                logger.log(.verbose, "Init response: \(responseBuffer.trimmingCharacters(in: .whitespacesAndNewlines))")
                continueInitSequence()
                responseBuffer = ""
            }
            return
        }
        
        isWaitingForResponse = false
        
        let text = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            logger.log(.verbose, "Empty response")
            return
        }
        
        // Parse the response and update vehicle data
        if let result = parser.parseResponse(text) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVehicleData(with: result)
                self.updateDataPoint(with: result)
            }
        }
    }
    
    private func updateVehicleData(with result: OBD2ParseResult) {
        switch result {
        case .speed(let speed):
            vehicleData.speed = speed
            vehicleData.updateEfficiency()
        case .longdistance(let longdistance):
            vehicleData.longdistance = longdistance
            
            // Set initial distance on first reading
            if initialLongDistance == nil {
                initialLongDistance = longdistance
                vehicleData.relativeDistance = 0.0
            } else {
                // Calculate relative distance from initial reading
                vehicleData.relativeDistance = longdistance - (initialLongDistance ?? 0)
            }
        case .batteryCurrent(let current):
            vehicleData.batteryCurrent = current
            vehicleData.updatePowerAndEfficiency()
        case .voltage(let voltage):
            vehicleData.voltage = voltage
            vehicleData.updatePowerAndEfficiency()
        case .stateOfCharge(let soc):
            vehicleData.stateOfCharge = soc
        case .ambientTemperature(let fahrenheit):
            vehicleData.ambientTempF = fahrenheit
        }
    }
    
    private func updateDataPoint(with result: OBD2ParseResult) {
        // Update the current data point with each parsed result
        switch result {
        case .speed(let speed):
            currentDataPoint.speedKmh = Int(speed * 1.60934) // Convert mph to km/h
        case .batteryCurrent(let current):
            currentDataPoint.currentAmps = current
        case .voltage(let voltage):
            currentDataPoint.voltageVolts = voltage
        case .stateOfCharge(let soc):
            currentDataPoint.soc = soc
        case .longdistance(let longdistance):
            currentDataPoint.distanceMi = longdistance
        case .ambientTemperature(let fahrenheit):
            currentDataPoint.ambientTempF = fahrenheit
        }
        
        // Save data point periodically (based on timer duration and command count)
        let commandCount = (fastPollingEnabled && !isDoingFullSweep) ? 1 : fetchCommands.count
        let saveInterval = dataTimerDuration * Double(commandCount) * 1.2
        if Date().timeIntervalSince(currentDataPoint.timestamp) >= saveInterval {
            saveCurrentDataPoint()
        }
    }
    
    private func saveCurrentDataPoint() {
        guard let dataStore = dataStore else { return }
        
        // Create a new data point with current timestamp
        let dataPointToSave = currentDataPoint
        
        // Only save if we have at least some data
        if dataPointToSave.speedKmh != nil ||
           dataPointToSave.currentAmps != nil ||
           dataPointToSave.voltageVolts != nil ||
           dataPointToSave.soc != nil {
            dataStore.saveDataPoint(dataPointToSave)
            logger.log(.verbose, "Saved data point to local storage")
        }
        
        // Reset for next interval
        currentDataPoint = VehicleDataPoint(timestamp: Date())
    }
    
    func resetDistance() {
        DispatchQueue.main.async {
            // Reset the baseline to current longdistance reading
            self.initialLongDistance = self.vehicleData.longdistance
            self.vehicleData.relativeDistance = 0.0
        }
        logger.log(.info, "Distance reset to zero")
    }
    
    private func stopAllTimers() {
        [dataTimer, initResponseTimer].forEach { $0?.invalidate() }
        dataTimer = nil
        initResponseTimer = nil
        isWaitingForResponse = false
        isInitializing = false
        
        // Save any pending data
        saveCurrentDataPoint()
    }
    
    deinit {
        stopAllTimers()
    }
}

