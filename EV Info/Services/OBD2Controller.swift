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
    
    @Published var vehicleData = VehicleData()
    
    // Timers and state
    private var dataTimer: Timer?
    private var initResponseTimer: Timer?
    private var currentCommandIndex = 0
    private var isWaitingForResponse = false
    private var responseBuffer = ""
    private var initCommandIndex = 0
    private var isInitializing = false
    
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
    init(connection: BLEConnection, parser: OBD2Parser, logger: Logger) {
        self.connection = connection
        self.parser = parser
        self.logger = logger
        
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startDataFetching()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sendNextInitCommand()
            }
        }
    }
    
    private func startDataFetching() {
        logger.log(.info, "Starting periodic data fetching")
        
        dataTimer?.invalidate()
        currentCommandIndex = 0
        isWaitingForResponse = false
        
        dataTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
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
        
        let command = fetchCommands[currentCommandIndex]
        let data = (command + "\r").data(using: .utf8)!
        
        logger.log(.verbose, "Sending: \(command)")
        connection.writeData(data)
        isWaitingForResponse = true
        
        currentCommandIndex = (currentCommandIndex + 1) % fetchCommands.count
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
            DispatchQueue.main.async {
                self.updateVehicleData(with: result)
            }
        }
    }
    
    private func updateVehicleData(with result: OBD2ParseResult) {
        switch result {
        case .speed(let speed):
            vehicleData.speed = speed
            vehicleData.updateEfficiency()
        case .distance(let distance):
            vehicleData.updateEfficiency()
        case .batteryCurrent(let current):
            vehicleData.batteryCurrent = current
            vehicleData.updatePowerAndEfficiency()
        case .voltage(let voltage):
            vehicleData.voltage = voltage
            vehicleData.updatePowerAndEfficiency()
        case .stateOfCharge(let soc):
            vehicleData.stateOfCharge = soc
        }
    }
    
    private func stopAllTimers() {
        [dataTimer, initResponseTimer].forEach { $0?.invalidate() }
        dataTimer = nil
        initResponseTimer = nil
        isWaitingForResponse = false
        isInitializing = false
    }
    
    deinit {
        stopAllTimers()
    }
}
