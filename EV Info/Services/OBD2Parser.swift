import Foundation

class OBD2Parser {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func parseResponse(_ text: String) -> OBD2ParseResult? {
        let cleanText = cleanResponseText(text)

        // Extended PIDs (Service 0x22 responses start with 62)
        // Order matters: check longer prefixes first to avoid ambiguity
        if cleanText.contains("6240D4") {
            return parseBatteryCurrent(cleanText)
        } else if cleanText.contains("62000D") {
            return parseVehicleSpeed(cleanText)
        } else if cleanText.contains("622885") {
            return parseVoltage(cleanText)
        } else if cleanText.contains("628334") {
            return parseStateOfCharge(cleanText)
        } else if cleanText.contains("6243AF") {
            return parseSOCHD(cleanText)
        } else if cleanText.contains("62434F") {
            return parseBatteryAvgTemp(cleanText)
        } else if cleanText.contains("624349") {
            return parseBatteryMaxTemp(cleanText)
        } else if cleanText.contains("62434A") {
            return parseBatteryMinTemp(cleanText)
        } else if cleanText.contains("6241A4") {
            return parseBatteryCoolantTemp(cleanText)
        } else if cleanText.contains("6241B2") {
            return parseHVACMeasuredPower(cleanText)
        } else if cleanText.contains("6241B1") {
            return parseHVACCommandedPower(cleanText)
        } else if cleanText.contains("62451F") {
            return parseACCompressor(cleanText)
        } else if cleanText.contains("6245F9") {
            return parseBatteryCapacity(cleanText)
        } else if cleanText.contains("624357") {
            return parseBatteryResistance(cleanText)
        } else if cleanText.contains("4131") {
            return parseVehicleDistance(cleanText)
        } else if cleanText.contains("4146") {
            return parseAmbientTemperature(cleanText)
        } else {
            parseOtherResponse(text)
            return nil
        }
    }

    private func cleanResponseText(_ text: String) -> String {
        return text.replacingOccurrences(of: " ", with: "")
                  .replacingOccurrences(of: "\r", with: "")
                  .replacingOccurrences(of: "\n", with: "")
    }

    // MARK: - Speed (22000D → 62000D, 1 byte, A = km/h)
    private func parseVehicleSpeed(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "62000D"),
              String(cleanText[range.upperBound...]).count >= 2 else { return nil }

        let speedHex = String(cleanText[range.upperBound...].prefix(2))
        guard let speedValue = Int(speedHex, radix: 16) else { return nil }

        let speedMph = Double(speedValue) * 0.621371
        logger.log(.data, "Speed: \(Int(speedMph)) mph")
        return .speed(speedMph)
    }

    // MARK: - Distance (0131 → 4131, 2 bytes, (A*256+B) km → miles)
    private func parseVehicleDistance(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "4131"),
              String(cleanText[range.upperBound...]).count >= 4 else { return nil }

        let distHex = String(cleanText[range.upperBound...].prefix(4))
        let aHex = String(distHex.prefix(2))
        let bHex = String(distHex.suffix(2))

        guard let A = Int(aHex, radix: 16),
              let B = Int(bHex, radix: 16) else { return nil }

        let distanceKm = A * 256 + B
        let distanceMiles = Double(distanceKm) * 0.621371

        logger.log(.data, "Distance: \(Int(distanceMiles)) mi")
        return .longdistance(distanceMiles)
    }

    // MARK: - Ambient Temperature (0146 → 4146, 1 byte, A-40 °C → °F)
    private func parseAmbientTemperature(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "4146"),
              String(cleanText[range.upperBound...]).count >= 2 else { return nil }

        let aHex = String(cleanText[range.upperBound...].prefix(2))
        guard let A = Int(aHex, radix: 16) else { return nil }

        let celsius = Double(A) - 40.0
        let fahrenheit = (celsius * 9.0 / 5.0) + 32.0

        logger.log(.data, String(format: "Ambient: %.1f °F", fahrenheit))
        return .ambientTemperature(fahrenheit)
    }

    // MARK: - HV Battery Current HD (2240D4 → 6240D4, 2 bytes, Signed(A)*256+B / 20)
    private func parseBatteryCurrent(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6240D4") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse current")
            return nil
        }

        let signedA = A < 128 ? A : A - 256
        let current = Double(signedA * 256 + B) / 20.0

        logger.log(.data, "Current: \(String(format: "%.1f", current)) A")
        return .batteryCurrent(current)
    }

    // MARK: - HV Pack Voltage (222885 → 622885, 2 bytes, (A*256+B) / 2)
    private func parseVoltage(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "622885") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse voltage")
            return nil
        }

        let voltage = Double(A * 256 + B) / 2.0
        logger.log(.data, "Voltage: \(String(format: "%.1f", voltage)) V")
        return .voltage(voltage)
    }

    // MARK: - State of Charge Displayed (228334 → 628334, 1 byte, A*100/255)
    private func parseStateOfCharge(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "628334") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse SoC")
            return nil
        }

        let soc = Double(A) * 100.0 / 255.0
        logger.log(.data, "SoC: \(String(format: "%.1f", soc))%")
        return .stateOfCharge(soc)
    }

    // MARK: - SOC HD Raw (2243AF → 6243AF, 2 bytes, (A*256+B)*100/65535)
    private func parseSOCHD(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6243AF") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse SOC HD")
            return nil
        }

        let soc = Double(A * 256 + B) * 100.0 / 65535.0
        logger.log(.data, "SOC HD: \(String(format: "%.2f", soc))%")
        return .socHD(soc)
    }

    // MARK: - Battery Avg Temperature (22434F → 62434F, 1 byte, A-40 °C)
    private func parseBatteryAvgTemp(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "62434F") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse battery avg temp")
            return nil
        }

        let tempC = Double(A) - 40.0
        logger.log(.data, "Batt Avg Temp: \(String(format: "%.0f", tempC)) °C")
        return .batteryAvgTemp(tempC)
    }

    // MARK: - Battery Max Temperature (224349 → 624349, 1 byte, A-40 °C)
    private func parseBatteryMaxTemp(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "624349") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse battery max temp")
            return nil
        }

        let tempC = Double(A) - 40.0
        logger.log(.data, "Batt Max Temp: \(String(format: "%.0f", tempC)) °C")
        return .batteryMaxTemp(tempC)
    }

    // MARK: - Battery Min Temperature (22434A → 62434A, 1 byte, A-40 °C)
    private func parseBatteryMinTemp(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "62434A") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse battery min temp")
            return nil
        }

        let tempC = Double(A) - 40.0
        logger.log(.data, "Batt Min Temp: \(String(format: "%.0f", tempC)) °C")
        return .batteryMinTemp(tempC)
    }

    // MARK: - Battery Coolant Temperature (2241A4 → 6241A4, 1 byte, A-40 °C)
    private func parseBatteryCoolantTemp(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6241A4") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse battery coolant temp")
            return nil
        }

        let tempC = Double(A) - 40.0
        logger.log(.data, "Coolant Temp: \(String(format: "%.0f", tempC)) °C")
        return .batteryCoolantTemp(tempC)
    }

    // MARK: - HVAC Measured Power (2241B2 → 6241B2, 2 bytes, Signed(A)*256+B watts)
    private func parseHVACMeasuredPower(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6241B2") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse HVAC measured power")
            return nil
        }

        let signedA = A < 128 ? A : A - 256
        let watts = Double(signedA * 256 + B)

        logger.log(.data, "HVAC Measured: \(Int(watts)) W")
        return .hvacMeasuredPower(watts)
    }

    // MARK: - HVAC Commanded Power (2241B1 → 6241B1, 2 bytes, Signed(A)*256+B watts)
    private func parseHVACCommandedPower(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6241B1") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse HVAC commanded power")
            return nil
        }

        let signedA = A < 128 ? A : A - 256
        let watts = Double(signedA * 256 + B)

        logger.log(.data, "HVAC Commanded: \(Int(watts)) W")
        return .hvacCommandedPower(watts)
    }

    // MARK: - A/C Compressor On/Off (22451F → 62451F, 1 byte, A-1 → bool)
    private func parseACCompressor(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "62451F") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 1,
              let A = Int(hexParts[0], radix: 16) else {
            logger.log(.warning, "Failed to parse A/C compressor")
            return nil
        }

        let isOn = (A - 1) != 0
        logger.log(.data, "A/C Compressor: \(isOn ? "ON" : "OFF")")
        return .acCompressorOn(isOn)
    }

    // MARK: - Battery Capacity (2245F9 → 6245F9, 2 bytes, (A*256+B)/100 Ah)
    private func parseBatteryCapacity(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "6245F9") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse battery capacity")
            return nil
        }

        let capacityAh = Double(A * 256 + B) / 100.0
        logger.log(.data, "Battery Capacity: \(String(format: "%.1f", capacityAh)) Ah")
        return .batteryCapacityAh(capacityAh)
    }

    // MARK: - Battery Resistance (224357 → 624357, 2 bytes, (A*256+B)/10 mΩ)
    private func parseBatteryResistance(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "624357") else { return nil }
        let afterPattern = String(cleanText[range.upperBound...])

        let hexParts = extractHexParts(from: afterPattern)
        guard hexParts.count >= 2,
              let A = Int(hexParts[0], radix: 16),
              let B = Int(hexParts[1], radix: 16) else {
            logger.log(.warning, "Failed to parse battery resistance")
            return nil
        }

        let resistanceMOhm = Double(A * 256 + B) / 10.0
        logger.log(.data, "Battery Resistance: \(String(format: "%.1f", resistanceMOhm)) mΩ")
        return .batteryResistance(resistanceMOhm)
    }

    // MARK: - Helpers

    private func parseOtherResponse(_ text: String) {
        if text.contains("OK") {
            logger.log(.verbose, "Command OK")
        } else if text.contains("?") || text.contains("ERROR") {
            logger.log(.warning, "Command error: \(text)")
        } else {
            logger.log(.verbose, "Other: \(text)")
        }
    }

    private func extractHexParts(from text: String) -> [String] {
        var hexParts: [String] = []
        for i in stride(from: 0, to: text.count, by: 2) {
            let start = text.index(text.startIndex, offsetBy: i)
            guard text.distance(from: start, to: text.endIndex) >= 2 else { break }
            let end = text.index(start, offsetBy: 2)
            hexParts.append(String(text[start..<end]))
        }
        return hexParts
    }
}

enum OBD2ParseResult {
    case speed(Double)              // mph (from 22000D)
    case longdistance(Double)       // miles (from 0131)
    case batteryCurrent(Double)     // Amps (from 2240D4 HD)
    case voltage(Double)            // Volts (from 222885, /2)
    case stateOfCharge(Double)      // % displayed (from 228334)
    case ambientTemperature(Double) // °F (from 0146)
    case socHD(Double)              // % raw (from 2243AF)
    case batteryAvgTemp(Double)     // °C (from 22434F)
    case batteryMaxTemp(Double)     // °C (from 224349)
    case batteryMinTemp(Double)     // °C (from 22434A)
    case batteryCoolantTemp(Double) // °C (from 2241A4)
    case hvacMeasuredPower(Double)  // Watts (from 2241B2)
    case hvacCommandedPower(Double) // Watts (from 2241B1)
    case acCompressorOn(Bool)       // (from 22451F)
    case batteryCapacityAh(Double)  // Ah (from 2245F9)
    case batteryResistance(Double)  // mΩ (from 224357)
}
