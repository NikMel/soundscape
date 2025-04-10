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
//    private var logLocationFilter = LocationUpdateFilter(minTime: 10.0, minDistance: 50.0)

    private let pollingInterval: TimeInterval = 10.0


    
    // MARK: - Public Interface
    
    static let shared = LogSession() // Singleton for simplicity, adjust if needed
    
    private init() { }
    
  
    
    func create(sessionName: String, shouldPollLocation: Bool = true) { // Added shouldPollLocation param
        self.sessionName = sessionName
        self.startTime = Date()
        self.logs.removeAll()
        self.isActive = true
        let columns = "Timestamp,latitude,longitude,Cadence,Event,Heading"
        self.appendLog(entry: columns, includeTimestamp: false)
        appendLog(entry: "-,-,-,LOG_START,-")
        if shouldPollLocation { // Poll only if true
            startLocationPolling()
        } else {
            print("[DEBUG] LogSession: Polling disabled for this session")
        }
    }

    
    private func startLocationPolling() {
        let stepTracker = StepTracker()
        stepTracker.startTracking(interval: pollingInterval)
        locationTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            LogSession.logRow(steptracker: stepTracker)// Call the logRow method to log the location entry
        }
        
//        locationTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
//                guard let currentLocation = LocationLogger.getCurrentLocation(),
//                      self.logLocationFilter.shouldUpdate(location: currentLocation) else {
//                    return // Skip logging if no location or no meaningful movement
//                }
//                
//                if let locationEntry = LocationLogger.getLocationEntry(for: currentLocation) {
//                    self.appendLog(entry: locationEntry)
//                }
//
//                self.logLocationFilter.update(location: currentLocation)
//            }
    }


    
    private func stopLocationPolling() {
        locationTimer?.invalidate()
        locationTimer = nil
    }
    
    // MARK: - Log Row Method

    
    public static func logRow(event: String = "NORMAL", steptracker: StepTracker  ) {
        
        let stepT = steptracker
        let coordinates = LocationLogger.getLocationEntry() ?? "Unknown Location"
        let cadence = stepT.currentCadenceValue
        let heading = AppContext.shared.geolocationManager.heading(orderedBy: [.course, .device, .user])
        let currentHeadingValue = heading.getHeadingValue()
        
        // Debug log for the logRow method execution
        print("[DEBUG] Logging new row: Location: \(coordinates), Cadence: \(cadence), Event: \(event), Heading: \(String(describing: currentHeadingValue))")
        
        // Format the log entry
        let logString = "\(coordinates),\(cadence),\(event),\(String(describing: currentHeadingValue))°"

        // Call appendLog to store this entry
        shared.appendLog(entry: logString)
    }

    
    
    func appendLog(entry: String, includeTimestamp: Bool = true) {
        // Debug log: Track if timestamp inclusion is requested
        print("Debug: Timestamp inclusion - \(includeTimestamp ? "Yes" : "No")")
        
        guard isActive else {
            return
        }
        
        let formattedEntry: String
        
        if includeTimestamp {
            // Debug log: Adding timestamp
            print("Debug: Adding timestamp to the log entry")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            formattedEntry = "\(timestamp),\(entry)"
        } else {
            // Debug log: No timestamp added
            print("Debug: No timestamp added")
            formattedEntry = entry
        }
        
        logs.append(formattedEntry)
        logs.forEach { print($0) }
    }


    func endSession() -> String {
        endTime = Date()
        appendLog(entry: "-,-,-,LOG_END,-")
        isActive = false
        stopLocationPolling() // 🔑 Stop polling when session ends
        return logs.joined(separator: "\n")
    }
}
