//
//  MapsDecoder.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation
import CoreLocation
import UIKit


struct HereRouteResponse: Decodable {
    struct Route: Decodable {
        struct Section: Decodable {
            struct Summary: Decodable {
                let duration: Int
            }
            let summary: Summary
        }
        let sections: [Section]
    }
    let routes: [Route]
}

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

    static func fetchWalkingTimeInSeconds(origin: CLLocation, destination: CLLocation) async -> Int? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "HereMapsAPIKey") as? String else {
            print("❌ Failed to load HERE Maps API key")
            return nil
        }

        let originCoord = "\(origin.coordinate.latitude),\(origin.coordinate.longitude)"
        let destinationCoord = "\(destination.coordinate.latitude),\(destination.coordinate.longitude)"
        let departureTime = ISO8601DateFormatter().string(from: Date())

        let urlString = "https://router.hereapi.com/v8/routes?transportMode=pedestrian&origin=\(originCoord)&destination=\(destinationCoord)&return=summary&departureTime=\(departureTime)&apiKey=\(apiKey)"

        print("🔍 Requesting route with URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(HereRouteResponse.self, from: data)
            if let duration = decodedResponse.routes.first?.sections.first?.summary.duration {
                print("✅ Walking duration received: \(duration) seconds")
                return duration
            } else {
                print("⚠️ Duration not found in route response")
                return nil
            }
        } catch {
            print("❌ Failed to fetch or decode route: \(error)")
            return nil
        }
    }

}
