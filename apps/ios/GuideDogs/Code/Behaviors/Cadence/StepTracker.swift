//
//  StepTracker.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-20.
//  Copyright © 2025 Soundscape community. All rights reserved.
//



import CoreMotion


class StepTracker {
    static let shared = StepTracker()
    private init() {
        print("[DEBUG] StepTracker initialized via shared singleton")
    }
    // gpt: as it is now this class must be treated as an instance but i wanted it to also be called using the shared way (i.e AltitudeManager.shared.getCurrentAltitude(), how to adjust so that there is a way to feetch any running instance and reuse if needed)
    private let pedometer = CMPedometer()
    private var timer: Timer?
    private var interval: TimeInterval = 10
    private var lastStepCount: Int = 0
    private var currentCadence: Double = 0.0  // gpt: Add attribute for cadence
    private var stepsInCurrentInterval: Int = 0
    private var totalStrides: Double = 0.0
    private var currentSpeed: Double = 0.0  // This will store the current speed
   
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
                self?.lastStepCount = steps.intValue
            }

                        // Fetch current pace (speed) from the pedometer
            if let pace = data?.currentPace {  // currentPace returns speed in meters per second
                // This method checks if the new speed differs significantly from the current speed.
                // If the difference exceeds a predefined threshold, it updates the speed; otherwise, it retains the current speed.
                self?.currentSpeed = self?.updateSpeed(newSpeed: pace.doubleValue) ?? 0.0
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.pedometer.queryPedometerData(from: Date().addingTimeInterval(-self.interval), to: Date()) { data, error in
                if let error = error {
                    LogSession.shared.appendLog(entry:"[StepTracker] Query error: \(error.localizedDescription)")
                    return
                }
                if let steps = data?.numberOfSteps {
                    self.stepsInCurrentInterval = steps.intValue
                    LogSession.shared.appendLog(entry:"[StepTracker] Steps in last \(self.interval)s: \(steps)")
                    _ = self.getCurrentCadence()
                    // LogSession.shared.appendLog(entry: "[StepTracker] stored speed (pace): \(self.currentSpeed) m/s")



                }
            }
        }
    }
    
    public var currentCadenceValue: Double {
        return self.currentCadence
    }

    private func updateSpeed(newSpeed: Double) -> Double {
        // Check if the difference between the current speed and the new speed is greater than 10%
        // Update the current speed using the smoothed value
        currentSpeed = updateSmoothedValue(previous: currentSpeed, newValue: newSpeed)
        
        // Log and send a notification about the speed change
        LogSession.shared.appendLog(entry: "[StepTracker] Smoothed speed updated: \(currentSpeed) m/s")
        NotificationCenter.default.post(name: Notification.Name.speedDidChange,
                        object: nil,
                        userInfo: ["speed": currentSpeed])
        return currentSpeed
    }

    private func isDifferenceGreaterThanTenPercent(value1: Double, value2: Double) -> Bool {
        let percentageDifference = abs(value1 - value2) / value2 * 100
        return percentageDifference > 1.5
    }

    private func updateSmoothedValue(previous: Double, newValue: Double, alpha: Double = 0.81) -> Double {
        let smoothedValue = alpha * newValue + (1 - alpha) * previous
        LogSession.shared.appendLog(entry: "[StepTracker] Smoothing applied: previous=\(previous), newValue=\(newValue), alpha=\(alpha), smoothedValue=\(smoothedValue)")
        return smoothedValue
    }
    
    // Add new method
    func getCurrentCadence() -> Double {
        let cadence = Double(stepsInCurrentInterval) / interval
        _ = self.getStridesForInterval()
        self.stepsInCurrentInterval = 0  // Reset steps for the next interval
        self.currentCadence = cadence
        return cadence
    }
    
    func stopTracking() {
        pedometer.stopUpdates()
        timer?.invalidate()
        LogSession.shared.appendLog(entry:"[StepTracker] Stopped step tracking")
    }

    func getStridesForInterval() -> Double {
        let strides = Double(stepsInCurrentInterval) / 2.0 // 1 stride = 2 steps
        totalStrides += strides // Update (cumulate) the total strides
        // LogSession.shared.appendLog(entry: "[StepTracker] Strides in last \(interval)s: \(strides), Total strides: \(totalStrides)")
        return strides
    }
}

