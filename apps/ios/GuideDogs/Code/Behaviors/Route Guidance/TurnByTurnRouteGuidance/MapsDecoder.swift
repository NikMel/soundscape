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
        if let key = Bundle.main.object(forInfoDictionaryKey: "ORSAPIKey") as? String {
            apiKey = key
        } else {
            apiKey = ""
            GDLogError(.routeGuidance, "Failed to load ORS API key")
        }
    }
    


    func fetchRoute(origin: String, destination: String) async -> (resolvedDestination: String?, coordinates: [(Double, Double, Double?, String)]?) {

        guard !apiKey.isEmpty else {
            GDLogError(.routeGuidance, "API key is missing, aborting request")
            return (nil, nil)
        }

        // 🔄 Fetch the closest address for the given destination coordinates
        let label = await reverseGeocodeORS(latLon: destination)
        let resolvedDestination = label?
            .split(separator: ",")
            .prefix(2)
            .joined(separator: ", ")

        if let resolved = resolvedDestination {
            print("Resolved Destination Address: \(resolved)")
        } else {
            print("Failed to resolve destination address, using raw coordinates")
        }

        // Example placeholder response (replace with actual API logic)
        do {
            guard let orsResponse = await fetchORSCoordinates(origin: origin, destination: destination) else {
                GDLogError(.routeGuidance, "Failed to fetch ORS route coordinates")
                return (resolvedDestination, nil)
            }
            
            print("📦 Received ORS route coordinates: \(orsResponse)")
            
            let turnByTurnCoords = try PolylineDecoder.orsDecode(from: orsResponse, routeName: label ?? "unknown")
            return (resolvedDestination, turnByTurnCoords)
        } catch {
            GDLogError(.routeGuidance, "Failed to fetch or decode: \(error)")
        }

        return (resolvedDestination, nil)
    }
    
    func fetchORSCoordinates(origin: String, destination: String) async -> [[Double]]? {
        
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ORSAPIKey") as? String, !apiKey.isEmpty else {
            GDLogError(.routeGuidance, "API key is missing, aborting request")
            return nil
        }
        
        let startComponents = origin.split(separator: ",").compactMap { Double($0) }
        let endComponents = destination.split(separator: ",").compactMap { Double($0) }

        guard startComponents.count == 2, endComponents.count == 2 else {
            print("❌ Invalid coordinate strings: origin=\(origin), destination=\(destination)")
            return nil
        }

        let start = [startComponents[1], startComponents[0]]
        let end = [endComponents[1], endComponents[0]]
        
        let url = URL(string: "https://api.openrouteservice.org/v2/directions/foot-walking/geojson")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "coordinates": [start, end]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let features = json["features"] as? [[String: Any]],
               let geometry = features.first?["geometry"] as? [String: Any],
               let coordinates = geometry["coordinates"] as? [[Double]] {
                
                return coordinates
            }
        } catch {
            print("❌ Error fetching or parsing route:", error)
        }
        
        return nil
    }
    
    private func reverseGeocodeORS(latLon: String) async -> String? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ORSAPIKey") as? String,
              !apiKey.isEmpty else {
            GDLogError(.routeGuidance, "Missing ORS API key")
            return nil
        }

        let parts = latLon.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }

        let urlString = "https://api.openrouteservice.org/geocode/reverse?api_key=\(apiKey)&point.lat=\(parts[0])&point.lon=\(parts[1])"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let features = json["features"] as? [[String: Any]],
               let props = features.first?["properties"] as? [String: Any],
               let label = props["label"] as? String {
                return label
            }
        } catch {
            GDLogError(.routeGuidance, "ORS reverse geocoding failed: \(error)")
        }

        return nil
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
            GDLogError(.routeGuidance, "Invalid URL for reverse geocoding: \(urlString)")
            return nil
        }
        
        
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
            GDLogError(.routeGuidance, "Failed to fetch or decode reverse geocoding response: \(error)")
        }
        
        return nil
    }

}
