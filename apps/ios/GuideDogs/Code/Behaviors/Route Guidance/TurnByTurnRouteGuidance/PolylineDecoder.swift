//
//  PolylineDecoder.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation

class PolylineDecoder {
    private static let FORMAT_VERSION = 1
    
    private static let DECODING_TABLE: [Int] = [
        62, -1, -1, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1,
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
        22, 23, 24, 25, -1, -1, -1, -1, 63, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
        36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    ]
    
    private static func decodeChar(_ char: Character) throws -> Int {
        guard let asciiValue = char.asciiValue, asciiValue >= 45, asciiValue - 45 < DECODING_TABLE.count else {
            throw NSError(domain: "Invalid encoding", code: 0, userInfo: nil)
        }
        let value = DECODING_TABLE[Int(asciiValue - 45)]
        if value < 0 {
            throw NSError(domain: "Invalid encoding", code: 0, userInfo: nil)
        }
        return value
    }
    
    private static func toSigned(_ value: Int) -> Int {
        return (value & 1) != 0 ? ~(value >> 1) : (value >> 1)
    }
    
    private static func decodeUnsignedValues(_ encoded: String) throws -> [Int] {
        var result = 0
        var shift = 0
        var values: [Int] = []
        
        for char in encoded {
            let value = try decodeChar(char)
            result |= (value & 0x1F) << shift
            
            if (value & 0x20) == 0 {
                values.append(result)
                result = 0
                shift = 0
            } else {
                shift += 5
            }
        }
        
        if shift > 0 {
            throw NSError(domain: "Invalid encoding", code: 0, userInfo: nil)
        }
        
        return values
    }
    
    private static func decodeHeader(_ values: inout [Int]) throws -> (precision: Int, thirdDim: Int, thirdDimPrecision: Int) {
        guard !values.isEmpty else {
            throw NSError(domain: "Invalid encoding: missing header", code: 0, userInfo: nil)
        }
        
        let version = values.removeFirst()
        if version != FORMAT_VERSION {
            throw NSError(domain: "Invalid format version", code: 0, userInfo: nil)
        }
        
        guard !values.isEmpty else {
            throw NSError(domain: "Invalid encoding: missing header values", code: 0, userInfo: nil)
        }
        
        let value = values.removeFirst()
        let precision = value & 15
        let thirdDim = (value >> 4) & 7
        let thirdDimPrecision = (value >> 7) & 15
        
        return (precision, thirdDim, thirdDimPrecision)
    }
    
    private static func addNicknames(to coordinates: [(Double, Double, Double?)]) -> [(Double, Double, Double?, String)] {
        var result: [(Double, Double, Double?, String)] = []
        for (index, coord) in coordinates.enumerated() {
            let nickname = "point_\(index + 1)"
            result.append((coord.0, coord.1, coord.2, nickname))
        }
        return result
    }
    
    static func decode(_ encoded: String) throws -> [(Double, Double, Double?, String)] {
        var values = try decodeUnsignedValues(encoded)
        let (precision, thirdDim, thirdDimPrecision) = try decodeHeader(&values)
        
        var lastLat = 0
        var lastLng = 0
        var lastZ = 0
        
        let factorDegree = pow(10.0, Double(precision))
        let factorZ = pow(10.0, Double(thirdDimPrecision))
        
        var coordinates: [(Double, Double, Double?)] = []
        
        while !values.isEmpty {
            lastLat += toSigned(values.removeFirst())
            guard !values.isEmpty else { throw NSError(domain: "Invalid encoding: incomplete coordinate", code: 0, userInfo: nil) }
            lastLng += toSigned(values.removeFirst())
            
            if thirdDim > 0 {
                guard !values.isEmpty else { throw NSError(domain: "Invalid encoding: missing third dimension", code: 0, userInfo: nil) }
                lastZ += toSigned(values.removeFirst())
                coordinates.append((Double(lastLat) / factorDegree, Double(lastLng) / factorDegree, Double(lastZ) / factorZ))
            } else {
                coordinates.append((Double(lastLat) / factorDegree, Double(lastLng) / factorDegree, nil))
            }
        }

        
        return addNicknames(to: coordinates)

    }
}


