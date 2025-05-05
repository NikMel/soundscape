//
//  StepTracker.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-20.
//  Copyright © 2025 Soundscape community. All rights reserved.
//



import CoreMotion

// gets stride number by dividing the number of steps by 2(ince stride is 2 steps)

class StepTracker {
    private let pedometer = CMPedometer()
    private var timer: Timer?
    private var interval: TimeInterval = 10
    private var lastStepCount: Int = 0
    private var currentCadence: Double = 0.0  // gpt: Add attribute for cadence
    private var stepsInCurrentInterval: Int = 0
    private var totalStrides: Double = 0.0



    
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


                }
            }
        }
    }
    
    public var currentCadenceValue: Double {
        return self.currentCadence
    }
    
    // Add new method
    func getCurrentCadence() -> Double {
        let cadence = Double(stepsInCurrentInterval) / interval
        _ = self.getStridesForInterval()
        self.stepsInCurrentInterval = 0  // Reset steps for the next interval
        LogSession.shared.appendLog(entry:"[StepTracker] Current cadence: \(cadence) steps/sec over interval: \(interval)s")
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
        LogSession.shared.appendLog(entry: "[StepTracker] Strides in last \(interval)s: \(strides), Total strides: \(totalStrides)")
        return strides
    }
}

