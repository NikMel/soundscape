//
//  LoggerController.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-18.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation

class LoggerController {
    
    static let shared = LoggerController() // Singleton instance
    
    private var isLoggingActive = false
    
    private init() { } // Prevent external init
    
    func toggleLogging(sessionName: String, shouldPollLocation: Bool = true, completion: @escaping () -> Void) { // Added shouldPollLocation param, default true
        if !isLoggingActive {
            print("[DEBUG] LoggerController: Starting new session '\(sessionName)' with polling: \(shouldPollLocation)")
            LogSession.shared.create(sessionName: sessionName, shouldPollLocation: shouldPollLocation) // Pass param here
            isLoggingActive = true
            completion()
        } else {
            print("[DEBUG] LoggerController: Ending session '\(LogSession.shared.sessionName)'")
            let allLogs = LogSession.shared.endSession()
            isLoggingActive = false
            
            LoggingContext.shared.writeRawStringToSeparateFile(allLogs) { fileURL in
                if let url = fileURL {
                    print("[DEBUG] LoggerController: Log stored at \(url.path)")
                    UseCaseLogger.shareLogFile(at: url)
                } else {
                    print("[ERROR] LoggerController: Failed to store log")
                    completion()
                }
            }
        }
    }
}
