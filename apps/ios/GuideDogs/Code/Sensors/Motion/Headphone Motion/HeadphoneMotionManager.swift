//
//  HeadphoneMotionManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreMotion
import Combine
import CocoaLumberjackSwift

// `CMHeadphoneMotionManager` is available on iOS 14.0+ and includes support for
// Apple AirPods Pro. Support for AirPods Max was not added until after iOS
// 14.0 (added in iOS 14.2 or 14.3)
//
// To ensure compatibility with AirPods Max, this feature will only be available for
// iOS 14.4+
@available(iOS 14.4, *)
// `NSObject` required for `CMHeadphoneMotionManagerDelegate`
class HeadphoneMotionManager: NSObject, UserHeadingProvider, Device {
    
    // MARK: Properties
    
    private let motionManager = CMHeadphoneMotionManager()
    private let queue: OperationQueue
    private let calibrationManager = HeadphoneCalibrationManager()
    private(set) var status: CurrentValueSubject<HeadphoneMotionStatus, Never> = .init(.inactive)
    // `UserHeadingProvider`
    weak var headingDelegate: UserHeadingProviderDelegate?
    let accuracy = 0.0
    let id: UUID
    // `Device`
    let name: String
    let model: String // = GDLocalizationUnnecessary("Apple AirPods")
    let type: DeviceType //= .apple
    var isConnected = false
    var isFirstConnection = false
    weak var deviceDelegate: DeviceDelegate?
    
    private var heading: Double? {
        didSet {
            guard oldValue != heading else {
                return
            }
            
            var headingValue: HeadingValue?
            
            if let heading = heading {
                headingValue = HeadingValue(heading, accuracy)
            }
            
            OperationQueue.main.addOperation { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                self.headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: headingValue)
            }
        }
    }
    
    // MARK: Initialization
    
    override convenience init() {
        let newid = UUID()
        self.init(id: newid, name: "unknown")
/*        name = "unknown"
        model = "Generic device"
        type = .generic

        // Initialize operation queue
        queue = OperationQueue()
        queue.name = "HeadphoneMotionUpdatesQueue"
        queue.qualityOfService = .userInteractive
        
        super.init()
        
        initializeMotionManager()
 */
    }
    
    convenience init(id: UUID, name: String) {
        self.init(id: id, name: name, modelName: "Apple AirPods", deviceType: .apple)
        /*        self.id = id
        self.name = name
        
        model = "Apple AirPods"
        type = .generic
        
        // Initialize operation queue
        queue = OperationQueue()
        queue.name = "HeadphoneMotionUpdatesQueue"
        queue.qualityOfService = .userInteractive
        
        super.init()
        
        initializeMotionManager() */
    }
    
    init(id: UUID, name: String, modelName: String, deviceType: DeviceType) {
        self.id = id
        self.name = name
        self.model = modelName
        self.type = deviceType
        
        GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManger.init, setting up...")
        // Initialize operation queue
        queue = OperationQueue()
        queue.name = "HeadphoneMotionUpdatesQueue"
        queue.qualityOfService = .userInteractive
        
        super.init()
        
        initializeMotionManager()
    }
    
    
    deinit {
        // Stop headphone motion updates
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func initializeMotionManager() {
        // Initialize `CMHeadphoneMotionManagerDelegate` for connecting and disconnecting
        // headphones
        motionManager.delegate = self
        
        if motionManager.isDeviceMotionAvailable == false || CMHeadphoneMotionManager.authorizationStatus() != .authorized {
            // `CMHeadphoneMotionManager` is not available on the device
            // e.g. Device is running iOS < 14.4
            //
            // Or `CMHeadphoneMotionManager` is not authorized
            //
            // Core Motion authorization is required for app use, so we can assume
            // that authorization status will always be `authorized`
            GDLogHeadphoneMotionInfo("EARS: Motion är INTE tillgänglig!")
            // Update state
            status.value = .unavailable
        }
        else {
            GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManger.initializeMotionManager, SEEMS like motion is available")
        }
    }
    
    // MARK: `UserHeadingProvider`
    
    func startUserHeadingUpdates() {
        guard status.value == .disconnected else {
            // Updates have already been started or
            // headphone motion is inactive / unavailable
            return
        }
        
        GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.startUserHeadingUpdates")
        
        GDATelemetry.track("headphone_motion.start_updates")
        
        // Start headphone motion updates
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (newValue, error) in
            guard let `self` = self else {
                return
            }
            
            if let newValue = newValue, let heading = self.calibrationManager.heading(for: newValue) {
                self.heading = heading
               // GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.motionupdate callback (status: \(self.status.value))")
                // `HeadphoneMotionManager` cannot begin acting like a `UserHeadingProvider` until
                // `CMHeadphoneMotionManager` connects and the first calibration completes
                //
                // If `calibrationManager` is returning a value for heading, then one or more calibrations
                // have completed. Update the device's state (e.g. update device delegate and process event)
                if self.status.value == .connected {
                    GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.motionupdate callback (status: \(self.status.value)) connected but not calibrated?")

                    // If needed, update status
                    self.status.value = .calibrated
                    
                    // After the headset calibrates,
                    // update device state
                    self.isConnected = true
                    self.deviceDelegate?.didConnectDevice(self)
                    
                    let state: HeadsetConnectionEvent.State = self.isFirstConnection ? .firstConnection : .reconnected
                    AppContext.process(HeadsetConnectionEvent(self.model, state: state))
                }
            } else {
                if let error = error {
                    GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.startUserHeadingUpdates ERROR: \(error.localizedDescription)")
                    DDLogError("EARS: Headphone motion updates failed: \(error.localizedDescription)")
                }
                GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.startUserHeadingUpdates FAILED with no error")
                // Heading is unknown
                self.heading = nil
            }
        }
    }
    
    func stopUserHeadingUpdates() {
        guard status.value == .inactive else {
            // Updates have already been stopped
            return
        }
        
        GDLogHeadphoneMotionInfo("Stopping headphone motion updates...")
        
        GDATelemetry.track("headphone_motion.stop_updates")
        
        // Stop headphone motion updates
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: `Device`
    
    static func setupDevice(id: UUID, name: String, modelName: String, deviceType: DeviceType, callback: @escaping DeviceCompletionHandler) {
        let device = HeadphoneMotionManager(id: id, name: name, modelName: modelName, deviceType: deviceType)
        
        if device.status.value == .unavailable {
            GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManger.setupDevice, device is not available")
            // Failure
            callback(.failure(.unavailable))
        } else {
            GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManger.setupDevice, device SEEMS available")
            // Success
            callback(.success(device))
            
            // Start updates to complete first
            // connection
            device.isFirstConnection = true
            device.connect()
        }
    }
    
    func connect() {
        guard status.value == .inactive else {
            // Updates have already been started
            return
        }
        GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.connect...")
        // Headphone motion is active, but headphones
        // are disconnected
        status.value = .disconnected
        
        // Start updates to connect
        startUserHeadingUpdates()
        GDLogHeadphoneMotionInfo("EARS: HeadphoneMotionManager.connect FINISHED (\(status.value)...")
    }
    
    func disconnect() {
        guard status.value > .inactive else {
            // Updates have already been stopped
            return
        }
        
        // Headphone motion is inactive
        status.value = .inactive
        
        // Stop updates to disconnect
        stopUserHeadingUpdates()
    }
    
}

@available(iOS 14.4, *)
extension HeadphoneMotionManager: CMHeadphoneMotionManagerDelegate {
    
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        GDLogHeadphoneMotionInfo("EARS: Headphone Motion Manager did connect...")
        
        GDATelemetry.track("headphone_motion.did_connect")
        
        // `HeapdhoneMotionManager` is connected, but has not calibrated
        // Update `HeadphoneMotionManager.status` to indicate that it is connected,
        // but wait until it is calibrated to update the device state
        status.value = .connected
        
        // User heading is unknown before headphones connect
        heading = nil
        
        // Start calibrating
        calibrationManager.startCalibrating()
    }
    
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        GDLogHeadphoneMotionInfo("EARS: Headphone Motion Manager did disconnect...")
        
        GDATelemetry.track("headphone_motion.did_disconnect")
        
        // Stop calibrating
        calibrationManager.stopCalibrating()
        
        // User heading is unknown after headphones disconnect
        heading = nil
        
        // Reset
        isFirstConnection = false
        
        if status.value >= .calibrated {
            // Update status
            status.value = .disconnected
            
            // If `HeadphoneMotionManager` was previously connected and
            // calibrated, update the device state
            isConnected = false
            deviceDelegate?.didDisconnectDevice(self)
            
            AppContext.process(HeadsetConnectionEvent(model, state: .disconnected))
        } else {
            // Update status
            status.value = .disconnected
        }
    }
    
}
