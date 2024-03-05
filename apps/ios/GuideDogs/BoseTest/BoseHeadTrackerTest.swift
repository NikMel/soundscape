//
//  BoseHeadTrackerTest.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-05.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
class BoseHeadTrackerTest: BaseBLEDevice {
    private var boseSensorConfig: CBCharacteristic?
    private var boseSensorData: CBCharacteristic?
    
    override class var services: [BLEDeviceService.Type] {
        get {
            return [BoseSensorService.self]
        }
    }
    // Denna anropas från BLEManager när en enhet hittades
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: .headset, delegate: delegate)

    }
    
    override func initializationComplete() {
        GDLogBLEInfo("caught init complete. Leta upp Charateristics")
        for service in self.peripheral.services! {
            if (service.uuid.uuidString == "FDD2") {
                for c in service.characteristics! {
                    if c.uuid.uuidString == BoseBLEDevice.BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
                        self.boseSensorConfig = c
                        self.peripheral.setNotifyValue(true, for: self.boseSensorConfig!)
//                        self.peripheral.readValue(for: self.boseHeadTrackingConfig!)
                        continue
                    }
                    if c.uuid.uuidString == BoseBLEDevice.BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
  //                      self.boseHeadTrackingData = c
  //                      boseDevice.setNotifyValue(true, for: self.boseHeadTrackingData!)
                        //   boseDevice.readValue(for: self.boseHeadTrackingData!)
                        continue
                    }
                    if c.uuid.uuidString == BoseBLEDevice.BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_INFO_CHARACTERISTIC.uuidString {
//                        self.boseHeadTrackingInfo = c
 //                       boseDevice.readValue(for: self.boseHeadTrackingInfo!)
                        continue
                    }
                }
            }
        }
                

        
        super.initializationComplete()
    }
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

    }
}

fileprivate struct BoseSensorService: BLEDeviceService {
    static var uuid: CBUUID = CBUUID(string: "FDD2")
    
    static var characteristicUUIDs: [CBUUID] = [
        CBUUID(string: "5AF38AF6-000E-404B-9B46-07F77580890B"), // Config
        CBUUID(string: "56A72AB8-4988-4CC8-A752-FBD1D54A953D") // Data
    ]
}
