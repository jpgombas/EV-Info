//
//  Logger.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import Foundation
import Combine

class Logger: ObservableObject {
    @Published var messages: [DebugMessage] = []
    @Published var logLevel: LogLevel = .info
    
    private let maxMessages = 30
    
    func log(_ level: LogLevel, _ message: String, forceShow: Bool = false) {
        let shouldShow = forceShow ||
                        (level == .error) ||
                        (level == .warning) ||
                        (logLevel == .verbose) ||
                        (logLevel == .info && level != .verbose) ||
                        (logLevel == .data && level == .data)
        
        guard shouldShow else { return }
        
        DispatchQueue.main.async {
            let debugMessage = DebugMessage("\(level.rawValue) \(message)")
            self.messages.append(debugMessage)
            
            if self.messages.count > self.maxMessages {
                self.messages.removeFirst()
            }
        }
    }
}
