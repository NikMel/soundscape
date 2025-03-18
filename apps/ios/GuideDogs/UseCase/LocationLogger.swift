//
//  LocationLogger.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-18.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import Foundation
import CoreLocation

class LocationLogger {
    static func logCurrentLocation() {
        if let location = AppContext.shared.geolocationManager.location {
            GDUseCaseTestInfo("📍 LocationLogger polled location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } else {
            print("📍 No location available yet")
        }
    }
}

