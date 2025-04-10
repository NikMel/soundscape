//
//  StepTracker.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-20.
//  Copyright © 2025 Soundscape community. All rights reserved.
//



import CoreMotion

class StepTracker {
    private let pedometer = CMPedometer()
    private var timer: Timer?
    private var interval: TimeInterval = 10
    private var lastStepCount: Int = 0
    private var currentCadence: Double = 0.0  // gpt: Add attribute for cadence


    
    func startTracking(interval: TimeInterval = 10) {
        self.interval = interval
        guard CMPedometer.isStepCountingAvailable() else {
            print("[StepTracker] Step counting not available")
            return
        }
        LogSession.shared.appendLog(entry: "-,-,-,STEP_TRACKING_STARTED_WITH_10s_INTERVAL,-")


        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            if let error = error {
                LogSession.shared.appendLog(entry:"[StepTracker] Pedometer error: \(error.localizedDescription)")
                return
            }
            if let steps = data?.numberOfSteps {
//                LogSession.shared.appendLog(entry:"[StepTracker] Steps counted so far: \(steps)")
                self?.lastStepCount = steps.intValue  // Store step count
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.pedometer.queryPedometerData(from: Date().addingTimeInterval(-self.interval), to: Date()) { data, error in
                if let error = error {
                    LogSession.shared.appendLog(entry:"[StepTracker] Query error: \(error.localizedDescription)")
                    return
                }
                if let steps = data?.numberOfSteps {
//                    LogSession.shared.appendLog(entry:"[StepTracker] Steps in last \(self.interval)s: \(steps)")
                    _ = self.getCurrentCadence()
                }
            }
        }
    }
    
    public var currentCadenceValue: Double {
        return self.currentCadence
    }
    
    // Add new method
    func getCurrentCadence() -> Double {
        let cadence = Double(lastStepCount) / interval
//        LogSession.shared.appendLog(entry:"[StepTracker] Current cadence: \(cadence) steps/sec over interval: \(interval)s")
        self.currentCadence = cadence
        return cadence
    }
    
    func stopTracking() {
        pedometer.stopUpdates()
        timer?.invalidate()
        LogSession.shared.appendLog(entry:"[StepTracker] Stopped step tracking")
    }
}

