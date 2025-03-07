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
    


    func fetchRoute(origin: String, destination: String) async -> [(Double, Double, Double?, String)]? {
        print("🚀 Fetching route from \(origin) to \(destination)")
        
        guard !apiKey.isEmpty else {
            print("❌ API key is missing, aborting request")
            return nil
        }

        let urlString = "https://router.hereapi.com/v8/routes?transportMode=pedestrian&origin=\(origin)&destination=\(destination)&return=polyline,turnbyturnactions&spans=names,streetAttributes&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }

        print("📡 Sending request to HERE Maps API: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            print("📥 Received response from HERE Maps API")

            let decodedResponse = try JSONDecoder().decode(HereRouteResponse.self, from: data)
            print("✅ Successfully decoded route response")

            if let route = decodedResponse.routes.first, let section = route.sections.first {
                print("🛣️ Route ID: \(route.id), Section ID: \(section.id)")
                let polyline = section.polyline
                print("🗺️ Encoded Polyline: \(polyline)")

                let decodedPolyline = try PolylineDecoder.decode(polyline)
                print("✅ Decoded Polyline: \(decodedPolyline)")

                return decodedPolyline
            } else {
                print("⚠️ No valid route found in API response")
            }
        } catch {
            print("❌ Failed to fetch or decode: \(error)")
        }

        return nil
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
