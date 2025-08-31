//
//  LogLevel.swift
//  EV Info
//
//  Created by Jason on 8/30/25.
//

import Foundation

enum LogLevel: String, CaseIterable {
    case verbose = "🔍"
    case info = "ℹ️"
    case success = "✅"
    case warning = "⚠️"
    case error = "❌"
    case data = "📊"
}

struct DebugMessage {
    let id = UUID()
    let message: String
    let timestamp: Date
    
    init(_ message: String) {
        self.message = message
        self.timestamp = Date()
    }
    
    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return "[\(formatter.string(from: timestamp))] \(message)"
    }
}
