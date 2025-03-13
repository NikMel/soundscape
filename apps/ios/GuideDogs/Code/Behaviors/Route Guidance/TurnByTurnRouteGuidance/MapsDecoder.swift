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
        } else {
            apiKey = ""
            print("❌ Failed to load HERE Maps API key")
        }
    }
    


    func fetchRoute(origin: String, destination: String) async -> (resolvedDestination: String?, coordinates: [(Double, Double, Double?, String)]?) {

        guard !apiKey.isEmpty else {
            print("❌ API key is missing, aborting request")
            return (nil, nil)
        }

        // 🔄 Fetch the closest address for the given destination coordinates
        let resolvedDestination = await getAddressLabel(for: destination)
        if let resolved = resolvedDestination {
            print("📍 Resolved Destination Address: \(resolved)")
        } else {
            print("⚠️ Failed to resolve destination address, using raw coordinates")
        }

        let urlString = "https://router.hereapi.com/v8/routes?transportMode=pedestrian&origin=\(origin)&destination=\(destination)&return=polyline,turnbyturnactions&spans=names,streetAttributes&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return (resolvedDestination, nil)
        }


        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let decodedResponse = try JSONDecoder().decode(HereRouteResponse.self, from: data)

            if let route = decodedResponse.routes.first, let section = route.sections.first {
                let polyline = section.polyline
                let coordinatesToInclude = filterCoordinates(from: decodedResponse)
                let decodedPolyline = try PolylineDecoder.decode(polyline, origin: origin, destination: destination, resolvedDestination: resolvedDestination, pickingOnly: coordinatesToInclude)

                return (resolvedDestination, decodedPolyline)
            } else {
                print("⚠️ No valid route found in API response")
            }
        } catch {
            print("❌ Failed to fetch or decode: \(error)")
        }

        return (resolvedDestination, nil)
    }
    
    private func filterCoordinates(from response: HereRouteResponse) -> [Int] {
        print("🔍 Filtering coordinates from route response")

        guard let firstRoute = response.routes.first, let firstSection = firstRoute.sections.first else {
            return []
        }

        let spanOffsets = firstSection.getSpanOffsets()

        return spanOffsets
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
    
    private func getAddressLabel(for destination: String) async -> String? {
        let urlString = "https://revgeocode.search.hereapi.com/v1/revgeocode?at=\(destination)&lang=en-US&apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for reverse geocoding: \(urlString)")
            return nil
        }
        
        print("📡 Sending request to HERE Maps Reverse Geocoding API: \(urlString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            if let items = json?["items"] as? [[String: Any]], let firstItem = items.first,
               let address = firstItem["address"] as? [String: Any], let street = address["street"] as? String {
                return street
            } else {
                print("No street found in response")
            }
        } catch {
            print("Failed to fetch or decode reverse geocoding response: \(error)")
        }
        
        return nil
    }

}
