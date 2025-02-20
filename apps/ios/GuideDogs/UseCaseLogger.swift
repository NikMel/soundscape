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
            print("[ERROR] No valid view controller to present UIActivityViewController")
            return
        }
        
        print("[DEBUG] shareLogs called with latest: \(latest)")

        let fileManager = FileManager.default
        let logDirectory = LoggingContext.shared.fileLogger.logFileManager.logsDirectory
        print("[DEBUG] Log Directory: \(logDirectory)")

        do {
            let logFiles = try fileManager.contentsOfDirectory(atPath: logDirectory)
                .map { URL(fileURLWithPath: logDirectory).appendingPathComponent($0) }
            
            print("[DEBUG] Found \(logFiles.count) log files.")
            
            guard !logFiles.isEmpty else {
                print("[DEBUG] No log files found.")
                return
            }
            
            if latest {
                let latestLogFile = logFiles.sorted { file1, file2 in
                    let date1 = (try? fileManager.attributesOfItem(atPath: file1.path)[.creationDate] as? Date) ?? Date.distantPast
                    let date2 = (try? fileManager.attributesOfItem(atPath: file2.path)[.creationDate] as? Date) ?? Date.distantPast
                    return date1 > date2
                }.first
                
                if let latestLogFile = latestLogFile {
                    print("[DEBUG] Latest Log File: \(latestLogFile.lastPathComponent)")
                    
                    // Check if the file actually exists
                    if fileManager.fileExists(atPath: latestLogFile.path) {
                        print("[DEBUG] Latest log file exists: \(latestLogFile.path)")
                    } else {
                        print("[ERROR] Latest log file does NOT exist: \(latestLogFile.path)")
                        return
                    }
                    
                    let activityViewController = UIActivityViewController(activityItems: [latestLogFile], applicationActivities: nil)
                    activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                        print("[DEBUG] Activity Completed: \(completed), Activity Type: \(String(describing: activityType)), Error: \(String(describing: error))")
                        
                        if let error = error {
                            print("[ERROR] Failed to present UIActivityViewController: \(error.localizedDescription)")
                        }
                        
                        if !completed {
                            print("[DEBUG] Sharing was cancelled or failed.")
                        } else {
                            print("[DEBUG] Sharing completed successfully.")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        topViewController.present(activityViewController, animated: true) {
                            print("[DEBUG] Presented UIActivityViewController for Latest Log File.")
                        }
                    }
                } else {
                    print("[DEBUG] No latest log file available after sorting.")
                }
            } else {
                print("[DEBUG] Sharing All Log Files:")
                logFiles.forEach { print("[DEBUG] File: \($0.lastPathComponent)") }
                
                let activityViewController = UIActivityViewController(activityItems: logFiles, applicationActivities: nil)
                activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                    print("[DEBUG] Activity Completed: \(completed), Activity Type: \(String(describing: activityType)), Error: \(String(describing: error))")
                    
                    if let error = error {
                        print("[ERROR] Failed to present UIActivityViewController: \(error.localizedDescription)")
                    }
                    
                    if !completed {
                        print("[DEBUG] Sharing was cancelled or failed.")
                    } else {
                        print("[DEBUG] Sharing completed successfully.")
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    topViewController.present(activityViewController, animated: true) {
                        print("[DEBUG] Presented UIActivityViewController for All Log Files.")
                    }
                }
            }
        } catch {
            print("[ERROR] Error retrieving log files: \(error.localizedDescription)")
        }
    }


    
    // Helper function to get the top-most view controller
    private static func getTopViewController() -> UIViewController? {
        guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topController = keyWindow.rootViewController
        
        // Traverse through presented view controllers
        while let presentedController = topController?.presentedViewController {
            // Skip the menu view controller
            if presentedController is MenuViewController {
                print("[DEBUG] Skipping MenuViewController as it is off-canvas.")
                break
            }
            topController = presentedController
        }
        
        print("[DEBUG] Presenting from Top Controller: \(String(describing: topController))")
        return topController
    }

}
