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
        } else {
            apiKey = ""
            print("❌ Failed to load HERE Maps API key")
        }
    }
    


    func fetchRoute(origin: String, destination: String) {  // <-- Adjusted to take origin and destination as parameters
        guard !apiKey.isEmpty else {
            print("❌ API key is missing, aborting request")
            return
        }

        let urlString = "https://router.hereapi.com/v8/routes?transportMode=pedestrian&origin=\(origin)&destination=\(destination)&return=polyline,turnbyturnactions&spans=names,streetAttributes&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return
        }

        print("📡 Sending request to HERE Maps API: \(urlString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Request failed: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("ℹ️ HTTP Status Code: \(httpResponse.statusCode)")
            }

            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                print("❌ No data received or failed to decode response")
                return
            }

            print("✅ Response received: \(responseString)")
            self.showAlert(message: responseString)
        }.resume()
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
