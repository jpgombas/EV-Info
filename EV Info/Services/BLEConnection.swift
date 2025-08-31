//
//  BLEConnection.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import Foundation
import CoreBluetooth
import Combine

class BLEConnection: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private let logger: Logger
    
    // Connection state
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var connectionStatus = "Disconnected"
    
    // Device configuration
    private let targetDeviceName = "VEEPEAK"
    private var targetDeviceUUID: UUID?
    
    // Callbacks
    var onDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    
    init(logger: Logger) {
        self.logger = logger
        super.init()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
            self.logger.log(.info, "BLE Connection initialized")
        }
    }
    
    func startScanning() {
        let state = centralManager.state
        logger.log(.verbose, "BLE state: \(state.rawValue)")
        
        switch state {
        case .poweredOn:
            isScanning = true
            connectionStatus = "Scanning..."
            logger.log(.info, "Started scanning for OBD2 devices")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        case .poweredOff:
            connectionStatus = "Bluetooth Off"
            logger.log(.error, "Bluetooth is powered off")
        case .unauthorized:
            connectionStatus = "Bluetooth Unauthorized"
            logger.log(.error, "Bluetooth access denied")
        default:
            connectionStatus = "Bluetooth Issue"
            logger.log(.warning, "Bluetooth state: \(state)")
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        logger.log(.info, "Stopped scanning")
        if !isConnected {
            connectionStatus = "Scan stopped"
        }
    }
    
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        logger.log(.info, "Disconnecting from device")
    }
    
    func writeData(_ data: Data) {
        guard let writeChar = writeCharacteristic else {
            logger.log(.error, "No write characteristic available")
            return
        }
        peripheral?.writeValue(data, for: writeChar, type: .withResponse)
    }
    
    func checkBluetoothStatus() {
        let stateDesc = getBluetoothStateDescription()
        logger.log(.info, "=== Bluetooth Status ===", forceShow: true)
        logger.log(.info, "State: \(stateDesc)", forceShow: true)
        logger.log(.info, "Target: \(targetDeviceName)", forceShow: true)
        logger.log(.info, "Connected: \(isConnected)", forceShow: true)
        logger.log(.info, "Scanning: \(isScanning)", forceShow: true)
        if let peripheral = peripheral {
            logger.log(.info, "Device: \(peripheral.name ?? "Unknown")", forceShow: true)
        }
        logger.log(.info, "=== End Status ===", forceShow: true)
    }
    
    private func getBluetoothStateDescription() -> String {
        switch centralManager?.state {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        case .none: return "Manager nil"
        @unknown default: return "Unknown state"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEConnection: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateDesc = getBluetoothStateDescription()
        connectionStatus = stateDesc == "Powered On" ? "Ready to connect" : stateDesc
        logger.log(.info, "Bluetooth: \(stateDesc)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"
        
        if deviceName != "Unknown Device" || RSSI.intValue > -70 {
            logger.log(.verbose, "Discovered: \(deviceName) (\(RSSI) dBm)")
        }
        
        let isOBD2Device = deviceName.uppercased().contains(targetDeviceName.uppercased()) ||
                          deviceName.uppercased().contains("OBD") ||
                          deviceName.uppercased().contains("ELM")
        
        if isOBD2Device {
            logger.log(.success, "Found OBD2 device: \(deviceName)")
            self.targetDeviceUUID = peripheral.identifier
            self.peripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            stopScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.log(.success, "Connected to \(peripheral.name ?? "device")")
        connectionStatus = "Connected - Discovering services..."
        isConnected = true
        onConnectionStateChanged?(true)
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.log(.error, "Connection failed: \(error?.localizedDescription ?? "Unknown")")
        connectionStatus = "Connection failed"
        onConnectionStateChanged?(false)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.log(.info, "Disconnected")
        isConnected = false
        connectionStatus = "Disconnected"
        self.peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        onConnectionStateChanged?(false)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEConnection: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        logger.log(.verbose, "Found \(services.count) services")
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            logger.log(.verbose, "Characteristic: \(characteristic.uuid.uuidString)")

            if notifyCharacteristic == nil && characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logger.log(.success, "Notify characteristic set")
            }

            if writeCharacteristic == nil &&
               (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)) {
                writeCharacteristic = characteristic
                logger.log(.success, "Write characteristic set")
            }
        }

        if writeCharacteristic != nil && notifyCharacteristic != nil {
            connectionStatus = "Connected - Ready"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        onDataReceived?(data)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let status = characteristic.isNotifying ? "enabled" : "disabled"
        logger.log(.verbose, "Notifications \(status)")
    }
}
