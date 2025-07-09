//
//  DebugLogger.swift
//  Quill
//
//  Created by Claude on 7/5/25.
//

import Foundation

class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var logs: [LogEntry] = []
    
    private init() {}
    
    func log(_ message: String, level: LogLevel = .info, source: String = "") {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            source: source
        )
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            // Keep only last 1000 entries
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
        }
        
        // Also print to console
        print("[\(level.rawValue)] \(source): \(message)")
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    func exportLogs() -> String {
        return logs.map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.source): \(entry.message)"
        }.joined(separator: "\n")
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let source: String
}

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    
    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
}