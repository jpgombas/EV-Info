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

    // Data collection
    private var currentDataPoint = VehicleDataPoint(timestamp: Date())

    // Tiered polling cycle tracking
    private var cycleCount = 0
    private let slowCycleInterval = 10  // Run slow tier every 5th cycle
    private var lastTripPollTime = Date.distantPast  // Force trip poll on first cycle
    private let tripPollInterval: TimeInterval = 600  // 10 minutes

    // Current command queue for this cycle
    private var currentCommandQueue: [String] = []
    private var currentQueueIndex = 0

    // Commands
    private let initCommands = ["ATZ", "ATE0", "ATL0", "ATS0", "ATH1", "ATSP6", "ATST96", "ATSH7E4"]

    // Fast tier: polled every cycle, all on BECM (7E4)
    private let fastCommands = [
        "2240D4",   // HV Battery Current (HD)
        "222885",   // HV Pack Voltage
        "22000D",   // Vehicle Speed (UDS on BECM)
    ]

    private let slowCommands = [
        "2243AF",   // SOC HD (raw)
        "228334",   // SOC Displayed
        "22434F",   // Battery avg temp
        "224349",   // Battery max temp
        "22434A",   // Battery min temp
        "2241A4",   // Battery coolant temp
        "2241B2",   // HVAC measured power
        "2241B1",   // HVAC commanded power
        "22451F",   // A/C compressor on/off
        // Header switch for distance & ambient temp
        "ATSH7DF",  // Switch to broadcast
        "0131",     // Distance traveled
        "0146",     // Ambient air temperature
        "ATSH7E4",  // Restore BECM header
    ]

    private let tripCommands = [
        "2245F9",   // Battery capacity (Ah)
        "224357",   // Battery resistance (mΩ)
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

    // MARK: - Command Queue Building

    private func buildCommandQueue() -> [String] {
        var commands = fastCommands

        if cycleCount % slowCycleInterval == 0 {
            commands += slowCommands
        }

        if Date().timeIntervalSince(lastTripPollTime) >= tripPollInterval {
            commands += tripCommands
            lastTripPollTime = Date()
        }

        return commands
    }

    // MARK: - Data Fetching

    private func startDataFetching() {
        logger.log(.info, "Starting periodic data fetching")

        dataTimer?.invalidate()
        isWaitingForResponse = false
        cycleCount = 0
        lastTripPollTime = Date.distantPast  // Force trip poll on first cycle

        currentCommandQueue = buildCommandQueue()
        currentQueueIndex = 0

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

        // Build next cycle's queue when current one is exhausted
        if currentQueueIndex >= currentCommandQueue.count {
            cycleCount += 1
            currentCommandQueue = buildCommandQueue()
            currentQueueIndex = 0
        }

        guard currentQueueIndex < currentCommandQueue.count else { return }

        let command = currentCommandQueue[currentQueueIndex]
        currentQueueIndex += 1

        let data = (command + "\r").data(using: .utf8)!
        logger.log(.verbose, "Sending: \(command)")
        connection.writeData(data)
        isWaitingForResponse = true

        startResponseTimeout(for: command)
    }

    private func startResponseTimeout(for command: String) {
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
            if initialLongDistance == nil {
                initialLongDistance = longdistance
                vehicleData.relativeDistance = 0.0
            } else {
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
        case .socHD(let soc):
            vehicleData.socHD = soc
        case .batteryAvgTemp(let tempC):
            vehicleData.batteryAvgTempC = tempC
        case .batteryMaxTemp(let tempC):
            vehicleData.batteryMaxTempC = tempC
        case .batteryMinTemp(let tempC):
            vehicleData.batteryMinTempC = tempC
        case .batteryCoolantTemp(let tempC):
            vehicleData.batteryCoolantTempC = tempC
        case .hvacMeasuredPower(let watts):
            vehicleData.hvacMeasuredPowerW = watts
        case .hvacCommandedPower(let watts):
            vehicleData.hvacCommandedPowerW = watts
        case .acCompressorOn(let isOn):
            vehicleData.acCompressorOn = isOn
        case .batteryCapacityAh(let ah):
            vehicleData.batteryCapacityAh = ah
        case .batteryResistance(let mOhm):
            vehicleData.batteryResistanceMOhm = mOhm
        }
    }

    private func updateDataPoint(with result: OBD2ParseResult) {
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
        case .socHD(let soc):
            currentDataPoint.socHD = soc
        case .batteryAvgTemp(let tempC):
            currentDataPoint.batteryAvgTempC = tempC
        case .batteryMaxTemp(let tempC):
            currentDataPoint.batteryMaxTempC = tempC
        case .batteryMinTemp(let tempC):
            currentDataPoint.batteryMinTempC = tempC
        case .batteryCoolantTemp(let tempC):
            currentDataPoint.batteryCoolantTempC = tempC
        case .hvacMeasuredPower(let watts):
            currentDataPoint.hvacMeasuredPowerW = watts
        case .hvacCommandedPower(let watts):
            currentDataPoint.hvacCommandedPowerW = watts
        case .acCompressorOn(let isOn):
            currentDataPoint.acCompressorOn = isOn
        case .batteryCapacityAh(let ah):
            currentDataPoint.batteryCapacityAh = ah
        case .batteryResistance(let mOhm):
            currentDataPoint.batteryResistanceMOhm = mOhm
        }

        // Save data point periodically
        let saveInterval = dataTimerDuration * Double(max(currentCommandQueue.count, 1)) * 1.2
        if Date().timeIntervalSince(currentDataPoint.timestamp) >= saveInterval {
            saveCurrentDataPoint()
        }
    }

    private func saveCurrentDataPoint() {
        guard let dataStore = dataStore else { return }

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
