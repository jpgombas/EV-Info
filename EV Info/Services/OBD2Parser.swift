import Foundation

class OBD2Parser {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func parseResponse(_ text: String) -> OBD2ParseResult? {
        let cleanText = cleanResponseText(text)
        
        if cleanText.contains("410D") {
            return parseVehicleSpeed(cleanText)
        } else if cleanText.contains("4131") {
            return parseVehicleDistance(cleanText)
        } else if cleanText.contains("0046") {
            return parseAmbientTemperature(cleanText)
        } else if cleanText.contains("622414") {
            return parseBatteryCurrent(cleanText)
        } else if cleanText.contains("622885") {
            return parseVoltage(cleanText)
        } else if cleanText.contains("628334") {
            return parseStateOfCharge(cleanText)
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
    // MARK: - Ambient Temperature
    private func parseAmbientTemperature(_ cleanText: String) -> OBD2ParseResult? {
        // Expect pattern containing "0046" followed by at least 1 byte for A
        guard let range = cleanText.range(of: "0046"),
              String(cleanText[range.upperBound...]).count >= 2 else { return nil }
        
        let aHex = String(cleanText[range.upperBound...].prefix(2))
        guard let A = Int(aHex, radix: 16) else { return nil }
        
        // PID 0x46: Ambient air temperature
        // Celsius = A - 40
        let celsius = Double(A) - 40.0
        // Fahrenheit per provided formula
        let fahrenheit = (celsius * 9.0 / 5.0) + 32.0
        
        logger.log(.data, String(format: "Ambient: %.1f °F", fahrenheit))
        return .ambientTemperature(fahrenheit)
    }
    // MARK: - Vehicle Speed
    private func parseVehicleSpeed(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "410D"),
              String(cleanText[range.upperBound...]).count >= 2 else { return nil }
        
        let speedHex = String(cleanText[range.upperBound...].prefix(2))
        guard let speedValue = Int(speedHex, radix: 16) else { return nil }
        
        let speedMph = Double(speedValue) * 0.62
        logger.log(.data, "Speed: \(Int(speedMph)) mph")
        return .speed(speedMph)
    }
    // MARK: - Vehicle Distance
    private func parseVehicleDistance(_ cleanText: String) -> OBD2ParseResult? {
        // Look for the response prefix "4131"
        guard let range = cleanText.range(of: "4131"),
              String(cleanText[range.upperBound...]).count >= 4 else { return nil }
        
        // Take the next 4 characters = 2 bytes (A and B)
        let distHex = String(cleanText[range.upperBound...].prefix(4))
        
        // Split into A and B
        let aHex = String(distHex.prefix(2))
        let bHex = String(distHex.suffix(2))
        
        guard let A = Int(aHex, radix: 16),
              let B = Int(bHex, radix: 16) else { return nil }
        
        // Formula: distance (km) = A * 256 + B
        let distanceKm = A * 256 + B
        let distanceMiles = Double(distanceKm) * 0.621371
        
        logger.log(.data, "Distance: \(Int(distanceMiles)) mi")
        return .longdistance(distanceMiles)
    }
    // MARK: - Current
    private func parseBatteryCurrent(_ cleanText: String) -> OBD2ParseResult? {
        guard let range = cleanText.range(of: "622414") else { return nil }
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
    // MARK: - Voltage
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
        
        let voltage = Double(A * 256 + B) / 100.0
        logger.log(.data, "Voltage: \(String(format: "%.1f", voltage)) V")
        return .voltage(voltage)
    }
    // MARK: - State of Charge
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
    case speed(Double)
    case longdistance(Double)
    case batteryCurrent(Double)
    case voltage(Double)
    case stateOfCharge(Double)
    case ambientTemperature(Double)
}

