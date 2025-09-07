//
//  MapsDecoder.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation
import UIKit

// MARK: - ORSRouteResponse Model
struct ORSRouteResponse: Codable {
    struct Feature: Codable {
        struct Geometry: Codable {
            let coordinates: [[Double]]
        }
        let geometry: Geometry
    }
    let features: [Feature]

    var routeCoordinates: [[Double]] { features.first?.geometry.coordinates ?? [] }
}

class MapsDecoder {
    

    private enum Constants {

        static let orsDirectionsURL: String = {
                    if let url = Bundle.main.object(forInfoDictionaryKey: "orsDirectionsURL") as? String, !url.isEmpty {
                        return url
                    } else {
                        GDLogError(.routeGuidance, "ORSDirectionsURL missing in Info.plist; defaulting to official ORS endpoint.")
                        return "https://api.openrouteservice.org/v2/directions/foot-walking/geojson"
                    }
                }()
        
        static let orsReverseGeocodeBaseURL: String = {
                    if let url = Bundle.main.object(forInfoDictionaryKey: "orsReverseGeocodeBaseURL") as? String, !url.isEmpty {
                        return url
                    } else {
                        GDLogError(.routeGuidance, "ORSReverseGeocodeBaseURL missing in Info.plist; defaulting to official ORS endpoint.")
                        return "https://api.openrouteservice.org/geocode/reverse"
                    }
                }()

    }
    


    func fetchRoute(origin: String, destination: String) async -> (resolvedDestination: String?, coordinates: [(Double, Double, Double?, String)]?) {
        
        // 🔄 Fetch the closest address for the given destination coordinates
        let label = await reverseGeocodeORS(latLon: destination)
        let resolvedDestination = label?
            .split(separator: ",")
            .prefix(2)
            .joined(separator: ", ")

        if let resolved = resolvedDestination {
        } else {
            GDLogError(.routeGuidance, "Failed to resolve destination address, using raw coordinates")
        }

        // 🧭 Get ORS route
        guard let orsResponse = await fetchORSCoordinates(origin: origin, destination: destination) else {
            GDLogError(.routeGuidance, "❌ Failed to fetch ORS route coordinates — aborting.")
            showAlert(message: "Routing not possible at this moment. Try again in a bit.")
            return (resolvedDestination, nil)
        }


        let turnByTurnCoords = PolylineDecoder.orsDecode(
            from: orsResponse,
            routeName: label ?? "unknown",
            origin: origin,
            destination: destination
        )

        return (resolvedDestination, turnByTurnCoords)
    }

    
    func fetchORSCoordinates(origin: String, destination: String) async -> [[Double]]? {
        
        let startComponents = origin.split(separator: ",").compactMap { Double($0) }
        let endComponents = destination.split(separator: ",").compactMap { Double($0) }

        guard startComponents.count == 2, endComponents.count == 2 else {
            GDLogError(.routeGuidance, " Invalid coordinate strings: origin=\(origin), destination=\(destination)")
            return nil
        }

        let start = [startComponents[1], startComponents[0]]
        let end = [endComponents[1], endComponents[0]]
        
        let url = URL(string: Constants.orsDirectionsURL)!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Soundscape/1.0", forHTTPHeaderField: "User-Agent")
//      request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["coordinates": [start, end]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])


            do {
                let (data, _) = try await URLSession.shared.data(for: request)

                let decoded = try JSONDecoder().decode(ORSRouteResponse.self, from: data)

                return decoded.routeCoordinates
            } catch {
                GDLogError(.routeGuidance, "ORS fetch/parse error: \(error)")
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

        let urlString = "\(Constants.orsReverseGeocodeBaseURL)?point.lat=\(parts[0])&point.lon=\(parts[1])"

        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("Soundscape/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
//            let (data, _) = try await URLSession.shared.data(from: url)
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
