//
//  MapsDecoder.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation
import UIKit

class MapsDecoder {
    private let apiKey: String

    init() {
        if let key = Bundle.main.object(forInfoDictionaryKey: "HereMapsAPIKey") as? String {
            apiKey = key
            print("✅ Successfully loaded HERE Maps API key")
            showAlert(message: "API Key Loaded: \(apiKey)")
        } else {
            apiKey = ""
            print("❌ Failed to load HERE Maps API key")
            showAlert(message: "Error: API Key not found")
        }
    }

    private func showAlert(message: String) {
        DispatchQueue.main.async {
            if let topVC = UIApplication.shared.windows.first?.rootViewController {
                let alert = UIAlertController(title: "HERE Maps API", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                topVC.present(alert, animated: true)
            }
        }
    }
}
