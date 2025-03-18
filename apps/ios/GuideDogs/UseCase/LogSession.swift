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
    private var locationTimer: Timer?
    private let pollingInterval: TimeInterval = 7.0


    
    // MARK: - Public Interface
    
    static let shared = LogSession() // Singleton for simplicity, adjust if needed
    
    private init() { }
    
  
    
    func create(sessionName: String) {
        self.sessionName = sessionName
        self.startTime = Date()
        self.logs.removeAll()
        self.isActive = true
        appendLog(entry: "Session '\(sessionName)' started.")
        startLocationPolling()
        print("✅ LogSession: Session '\(sessionName)' started at \(String(describing: startTime))")
        
    }
    
    private func startLocationPolling() {
        print("🛰️ LogSession: Starting location polling every 20 seconds")
        locationTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            print("🛰️ LogSession: Polling location...")
            if let locationEntry = LocationLogger.getLocationEntry() {
                self.appendLog(entry: locationEntry)
            }
        }
    }

    
    private func stopLocationPolling() {
        locationTimer?.invalidate()
        locationTimer = nil
    }
    
    
    func appendLog(entry: String) {
        guard isActive else {
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let formattedEntry = "[\(timestamp)] [USECASE] \(entry)"
        logs.append(formattedEntry)
        print("📜 Current logs:")
        logs.forEach { print($0) }
    }

    func endSession() -> String {
        print("endSession called:")
        endTime = Date()
        appendLog(entry: "Session '\(sessionName)' ended.")
        isActive = false
        stopLocationPolling() // 🔑 Stop polling when session ends
        return logs.joined(separator: "\n")
    }
}
