//
//  PolylineDecoder.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation
import CoreLocation
import simd

class PolylineDecoder {
   
    private enum Constants {
        static let defaultRouteName = "unknown"
        static let maxRouteNameLength = 17
        static let simplificationEpsilon = 0.036  // 0.036 is best for now
    }
    
    static func orsDecode(from coordinates: [[Double]], routeName: String = Constants.defaultRouteName, origin: String? = nil, destination: String? = nil) -> [(Double, Double, Double?, String)] {
        var result: [(Double, Double, Double?, String)] = []
        
        print("🔍 Raw coordinate list (total \(coordinates.count)):")
        for (i, coord) in coordinates.enumerated() {
            print("   [\(i)] \(coord)")
        }
        
        let cartesianCoords = convertCoordinates(coordinates.map { ($0[1], $0[0], nil) }, toCartesian: true)
        let simplifiedIndices = simplifyPolyline(convertedCoordinates: cartesianCoords, epsilon: Constants.simplificationEpsilon, skip: false)
        
        print("🔍 Simplified indices (total \(simplifiedIndices.count)):")
        print(simplifiedIndices)
        
        
        
        
//        if let startCoord = makeLabeledCoordinate(from: origin, label: "Start", routeName: routeName) {
//            result.append(startCoord)
//        }
        
        
        for (index, i) in simplifiedIndices.enumerated() {
            guard i < coordinates.count, coordinates[i].count == 2 else {
                GDLogError(.routeGuidance, "Invalid coordinate at simplified index \(i)")
                continue
            }
            
            let coord = coordinates[i]
            let latitude = coord[0]
            let longitude = coord[1]
            
            let shortName = routeName.count > Constants.maxRouteNameLength ? String(routeName.prefix(Constants.maxRouteNameLength)) + "..." : routeName // gpt: this constant 13...
            let nickname = "~\(shortName) point\(index + 1)"
            
            result.append((longitude, latitude, nil, nickname))
            
        }
        
        if let endCoord = makeLabeledCoordinate(from: destination, label: "End", routeName: routeName) {
            result.append(endCoord)
            
        }
        return result
    }
    
    private static func makeLabeledCoordinate(from string: String?, label: String, routeName: String) -> (Double, Double, Double?, String)? {
        guard let string = string else { return nil }
        let parts = string.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }

        let shortName = routeName.count > Constants.maxRouteNameLength ? String(routeName.prefix(Constants.maxRouteNameLength)) + "..." : routeName // gpt: this constant 13...
        let nickname = "~\(shortName) \(label)"
        return (parts[0], parts[1], nil, nickname) // lon, lat
    }

    
    private static func convertCoordinates(_ coordinates: [(Double, Double, Double?)], toCartesian: Bool) -> [(Double, Double, Double?)] {

        return coordinates.map { (lon, lat, alt) in
            let phi = lat * .pi / 180  // Convert to radians
            let lambda = lon * .pi / 180
            let h = alt ?? 0.0

            // WGS 84 reference ellipsoid parameters
            let a = 6378137.0         // Semi-major axis (meters)
            let f = 1 / 298.257223563 // Flattening
            let e2 = f * (2 - f)      // Square of eccentricity

            let N = a / sqrt(1 - e2 * sin(phi) * sin(phi)) // Radius of curvature

            // Convert to ECEF
            let x = (N + h) * cos(phi) * cos(lambda)
            let y = (N + h) * cos(phi) * sin(lambda)
            let z = ((1 - e2) * N + h) * sin(phi)

            return (x, y, z)
        }
    }
    
    private static func simplifyPolyline(convertedCoordinates: [(Double, Double, Double?)], epsilon: Double, skip: Bool = false) -> [Int] {
        if skip {
            print("Skipping simplification. Returning all indices.")
            return Array(0..<convertedCoordinates.count)
        }
        
        guard convertedCoordinates.count > 2 else { return Array(0..<convertedCoordinates.count) }
        
        var stk: [(Int, Int)] = [(0, convertedCoordinates.count - 1)]  // Stack for segment indices
        let globalStartIndex = 0
        var indices = Array(repeating: true, count: convertedCoordinates.count) // Boolean array for filtering
        
        while !stk.isEmpty {
            let (startIndex, lastIndex) = stk.removeLast()
            
            var dmax = 0.0
            var index = startIndex

            for i in (startIndex + 1)..<lastIndex {
                if indices[i - globalStartIndex] {
                    let d = perpendicularDistance(point: convertedCoordinates[i],
                                                  lineStart: convertedCoordinates[startIndex],
                                                  lineEnd: convertedCoordinates[lastIndex])
                    if d > dmax {
                        index = i
                        dmax = d
                    }
                }
            }

            if dmax > epsilon {
                stk.append((startIndex, index))
                stk.append((index, lastIndex))
            } else {
                for i in (startIndex + 1)..<lastIndex {
                    indices[i - globalStartIndex] = false
                }
            }
        }

        // Extract and return indices of retained points
        return indices.enumerated().compactMap { $0.element ? $0.offset + 1 : nil }
    }
    
    private static func perpendicularDistance(point: (Double, Double, Double?),
                               lineStart: (Double, Double, Double?),
                               lineEnd: (Double, Double, Double?)) -> Double {
        let (x0, y0) = (point.0, point.1)
        let (x1, y1) = (lineStart.0, lineStart.1)
        let (x2, y2) = (lineEnd.0, lineEnd.1)

        let num = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denom = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        return denom != 0 ? num / denom : 0.0
    }

    



}


