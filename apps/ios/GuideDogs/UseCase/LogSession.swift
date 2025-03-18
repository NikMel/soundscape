//
//  LogSession.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-18.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation

class LogSession {
    
    // MARK: - Attributes
    
    private(set) var sessionName: String = ""
    private(set) var logs: [String] = []
    private(set) var startTime: Date?
    private(set) var endTime: Date?
    private(set) var isActive: Bool = false
    
    // MARK: - Public Interface
    
    static let shared = LogSession() // Singleton for simplicity, adjust if needed
    
    private init() { }
    
  
    
    func create(sessionName: String) {
        self.sessionName = sessionName
        self.startTime = Date()
        self.logs.removeAll()
        self.isActive = true
        appendLog(entry: "Session '\(sessionName)' started.")
        print("✅ LogSession: Session '\(sessionName)' started at \(String(describing: startTime))")
    }
    
    
    
    func appendLog(entry: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let formattedEntry = "[\(timestamp)] [USECASE] \(entry)"
        logs.append(formattedEntry)
        print("📜 Current logs:")
        logs.forEach { print($0) }
    }


    
    func endSession() -> String {
        endTime = Date()
        isActive = false
        appendLog(entry: "Session '\(sessionName)' ended.")
        return logs.joined(separator: "\n")
    }
}
