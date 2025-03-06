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
    


    func fetchRoute(origin: String, destination: String) async -> HereRouteResponse? {
        guard !apiKey.isEmpty else {
            print("❌ API key is missing, aborting request")
            return nil
        }

        let urlString = "https://router.hereapi.com/v8/routes?transportMode=pedestrian&origin=\(origin)&destination=\(destination)&return=polyline,turnbyturnactions&spans=names,streetAttributes&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return nil
        }

        print("📡 Sending request to HERE Maps API: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)  // <-- Uses async/await to wait for response

            if let httpResponse = response as? HTTPURLResponse {
                print("ℹ️ HTTP Status Code: \(httpResponse.statusCode)")
            }

            let decodedResponse = try JSONDecoder().decode(HereRouteResponse.self, from: data)
            if let destinationName = decodedResponse.routes.first?.sections.first?.spans?.last?.names?.first?.value {
                showAlert(message: "Destination: \(destinationName)")  // <-- Show destination name in alert
            }
            print("✅ Successfully decoded route")
            return decodedResponse  // <-- Returns HereRouteResponse directly

        } catch {
            print("❌ Failed to fetch or decode: \(error)")
            return nil
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
