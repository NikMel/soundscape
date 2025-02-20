//
//  UseCaseLogger.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-02-18.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

// flow: https://tinyurl.com/2unc3j6v and sequence: https://tinyurl.com/4jnnd5mc

import CocoaLumberjack
import UIKit  // Required for UIActivityViewController

// TODO: Redraw the design
// TODO: Make sure the most recent logs are being fetched
// TODO: Attach a filter around the log that only lets use case logs through
// TODO: Move all of this functionality to the use case logger

class UseCaseLogger: DDLogFileManagerDefault {
    
    override var logsDirectory: String {
        return "/your/custom/path"  // Set this to the desired directory
    }
    
    // MARK: - Share Logs Functionality
    static func shareLogs(latest: Bool) {
        guard let topViewController = getTopViewController() else {
            print("Error: No valid view controller to present UIActivityViewController")
            return
        }
        
        let fileManager = FileManager.default
        let logDirectory = LoggingContext.shared.fileLogger.logFileManager.logsDirectory

        do {
            let logFiles = try fileManager.contentsOfDirectory(atPath: logDirectory)
                .map { URL(fileURLWithPath: logDirectory).appendingPathComponent($0) }
            
            guard !logFiles.isEmpty else {
                print("No log files found.")
                return
            }
            
            if latest {
                // If latest is true, find the most recent log file
                let latestLogFile = logFiles.sorted { file1, file2 in
                    let date1 = (try? fileManager.attributesOfItem(atPath: file1.path)[.creationDate] as? Date) ?? Date.distantPast
                    let date2 = (try? fileManager.attributesOfItem(atPath: file2.path)[.creationDate] as? Date) ?? Date.distantPast
                    return date1 > date2
                }.first
                
                if let latestLogFile = latestLogFile {
                    print("Sharing Latest Log File: \(latestLogFile.lastPathComponent)")
                    let activityViewController = UIActivityViewController(activityItems: [latestLogFile], applicationActivities: nil)
                    topViewController.present(activityViewController, animated: true, completion: nil)
                } else {
                    print("No log files available after sorting.")
                }
            } else {
                // If latest is false, share all log files as before
                print("Sharing All Log Files:")
                logFiles.forEach { print($0.lastPathComponent) }
                
                let activityViewController = UIActivityViewController(activityItems: logFiles, applicationActivities: nil)
                topViewController.present(activityViewController, animated: true, completion: nil)
            }
        } catch {
            print("Error retrieving log files: \(error.localizedDescription)")
        }
    }
    
    // Helper function to get the top-most view controller
    private static func getTopViewController() -> UIViewController? {
        guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        var topController = keyWindow.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}
