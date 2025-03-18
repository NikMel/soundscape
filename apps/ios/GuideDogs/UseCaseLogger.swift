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


class UseCaseLogger: DDLogFileManagerDefault {
    
    override var logsDirectory: String {
        return "/your/custom/path"  // Set this to the desired directory
    }
    
    // MARK: - Share Logs Functionality
    static func shareLogFile(at fileURL: URL) {
            guard let topViewController = getTopViewController() else {
                print("[ERROR] No valid view controller to present UIActivityViewController")
                return
            }
            
            let fileManager = FileManager.default
            
            // Check if file exists
            guard fileManager.fileExists(atPath: fileURL.path) else {
                print("[ERROR] Log file does not exist at path: \(fileURL.path)")
                showAlert(on: topViewController, title: "File Not Found", message: "The selected log file does not exist.")
                return
            }
            
            print("[DEBUG] Sharing log file at path: \(fileURL.path)")
            
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                print("[DEBUG] Activity Completed: \(completed), Activity Type: \(String(describing: activityType)), Error: \(String(describing: error))")
                
                if let error = error {
                    print("[ERROR] Failed to present UIActivityViewController: \(error.localizedDescription)")
                    showAlert(on: topViewController, title: "Error", message: "Failed to share the log file.")
                } else if !completed {
                    print("[DEBUG] Sharing was cancelled or failed.")
                    showAlert(on: topViewController, title: "Share Failed", message: "Unable to share the log file.")
                } else {
                    print("[DEBUG] Sharing completed successfully.")
                }
            }
            
            DispatchQueue.main.async {
                topViewController.present(activityViewController, animated: true) {
                    print("[DEBUG] Presented UIActivityViewController for log file.")
                }
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
    
    // MARK: - Helper Method to Show Alert
    private static func showAlert(on viewController: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        DispatchQueue.main.async {
            viewController.present(alert, animated: true, completion: nil)
        }
    }


}
