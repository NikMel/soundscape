//
//  BoseBLEDevice.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-02-29.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
// TODO: Subklassa BaseBLEDevice, implementera Device (CalibratableDevice istället!) och UserHeadingProvider
// TODO: Implementera BoseReachability som försöker göra en Connect med timeout (se HeadPhoneReachability)
class BoseBLEDevice : NSObject {
    internal let DEVICE_NAME: String = "le-bose frames"
    struct BOSE_SERVICE_CONSTANTS {
        static let CBUUID_HEADTRACKING_SERVICE: CBUUID = CBUUID(string: "FDD2")
        static let CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC: CBUUID = CBUUID(string: "5AF38AF6-000E-404B-9B46-07F77580890B")
        static let CBUUID_HEADTRACKING_DATA_CHARACTERISTIC: CBUUID = CBUUID(string: "56A72AB8-4988-4CC8-A752-FBD1D54A953D")
        static let CBUUID_HEADTRACKING_INFO_CHARACTERISTIC: CBUUID = CBUUID(string: "855CB3E7-98FF-42A6-80FC-40B32A2221C1")
    }

    internal var centralManager: CBCentralManager!
    internal var bosePeripheral: CBPeripheral?
    internal var boseHeadTrackingService: CBService?
    internal var boseHeadTrackingConfig: CBCharacteristic?
    internal var boseHeadTrackingData: CBCharacteristic?
    internal var boseHeadTrackingInfo: CBCharacteristic?
    internal var eventProcessor = BoseEventProcessor()
    
    internal var isHeadtrackingStarted: Bool = false
    
    internal var queue = DispatchQueue(label: "services.soundscape.ble.ears")
    
    enum BoseConnectionState {
        case disconnected
        case disconnecting
        case connecting
        case connected
    }
    internal var state: BoseConnectionState
    
    override init(){
        self.state = .disconnected
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    
    func currentConnectionState() -> BoseConnectionState {
        return self.state
    }
    
    func connectToBose(){
        // Scan for Bose headsets. These should offer the service FDD2 which (might) provide headtracking sensor charateristcvs
        centralManager.scanForPeripherals(withServices: [BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE])
        self.state = .connecting
    }
    
    func disconnect() {
        guard let device = bosePeripheral, let cm = centralManager else {return}
        self.state = .disconnecting
        cm.cancelPeripheralConnection(device)
    }
    
    func startHeadTracking() {
        guard let config = eventProcessor.currentSensorConfig
        else {
            GDLogBLEError("Cannot START headtracking. Bose headphones are not ready")
            return
        }
        
        config.rotationPeriod = 80
        let myData = config.toConfigToData()
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = true
    }
    
    func stopHeadTracking() {
        guard let config = eventProcessor.currentSensorConfig
        else {
            GDLogBLEError("Cannot STOP headtracking. Bose headphones are not ready")
            return
        }

        config.rotationPeriod = 0
        let myData = config.toConfigToData()
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = false
    }
    
    func isHeadTrackingStarted() -> Bool {
        return self.isHeadtrackingStarted
    }
}

