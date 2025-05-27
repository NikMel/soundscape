//
//  AltitudeManager.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-05-24.
//  Copyright © 2025 Soundscape community. All rights reserved.
//
import CoreMotion // Add this near the top


class AltitudeManager {
    static let shared = AltitudeManager()
    private let altimeter = CMAltimeter()
    private var baselineAltitude: Double = 0.0
    private var relativeAltitude: Double = 0.0

    

    private init() {
        if let location = AppContext.shared.geolocationManager.location {
            baselineAltitude = location.altitude
            print("[DEBUG] Baseline altitude from Core Location: \(baselineAltitude) meters")
        } else {
            print("[DEBUG] No GPS location available to initialize baseline altitude.")
        }
        startAltitudeUpdates()
    }


    private func startAltitudeUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("[DEBUG] Altimeter not available on this device.")
            return
        }

        altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
            if let altitude = data?.relativeAltitude.doubleValue {
                self.relativeAltitude = altitude
                print("[DEBUG] Relative altitude change: \(altitude) meters")
            }
        }
    }

    func getCurrentAltitude() -> Double {
        let liveAltitude = baselineAltitude + relativeAltitude
        print("[DEBUG] Combined altitude: \(liveAltitude) meters (Baseline: \(baselineAltitude), Relative: \(relativeAltitude))")
        return liveAltitude
    }

}
