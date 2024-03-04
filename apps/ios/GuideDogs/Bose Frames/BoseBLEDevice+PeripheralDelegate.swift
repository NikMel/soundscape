//
//  BoseBLEDevice+PeripheralDelegate.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-02.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth

// TODO:
/*
 - (KLART) Skriv en manuell rutin som plockar bytes till structen (reverse byte order)
 - field 2 (normal order) verkar ha 0 rakt i söder!)
 - (SKIP?) Kan data från Bose vara två float och en int32 (Float = 4byte)
 - (TEST) Testa att skriva 768 och se om det stannar dataströmmen (gör en toggle i UI)
 - Lista ut om någon av överiga fields kan vara pitch / yaw / roll och accuracy (kan det vara field6; gick från högt nummer till lågt och stabilt)
 - Hur kan vi skriva en BoseBLEDevice som är kompatibel men HeadphoneMotionManager
 */

extension BoseBLEDevice: CBPeripheralDelegate {
    
    internal func writeValueToConfig(value: Data){
        guard
            let device = bosePeripheral,
            let configCharacteristic = boseHeadTrackingConfig
        else {
            GDLogBLEError("EARS: Trying to write to config, but something failed...")
            return
        }
        
        if(self.state != .connected) {
            GDLogBLEError("EARS: Trying to write to config, but state != connected.")
        }
        device.writeValue(value, for: configCharacteristic, type: .withResponse)
    }
    
    // MARK: READ VALUE
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        if let error = error {
            GDLogBLEError("EARS: Error reading value from charateristic \(characteristic.uuid.uuidString): \(error)")
            return
        }
        guard let value = characteristic.value else {
            GDLogBLEInfo("EARS: Read value from CHARACTERISTIC \(characteristic.uuid.uuidString) but it was nil")
            return
        }
        
        if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
            eventProcessor.onOrientationEvent(eventData: value)
            // Also request read from INFO
            peripheral.readValue(for: boseHeadTrackingInfo!)
        } else if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
            GDLogBLEInfo("READ sensor CONFIG value: \(String(describing: characteristic.value?.debugDescription))")
            let valueAsArr = BoseEventProcessor.dataToByteArray(data: characteristic.value!)
            GDLogBLEInfo("READ sensor CONFIG value (arrtest): \(valueAsArr)")
            eventProcessor.currentSensorConfig = BoseSensorConfiguration.parseValue(data: value)
        } else if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_INFO_CHARACTERISTIC.uuidString {
//            GDLogBLEInfo("READ sensor INFO value: \(String(describing: characteristic.value?.debugDescription))")
            let valueAsArr = BoseEventProcessor.dataToByteArray(data: characteristic.value!)
//            eventProcessor.currentSensorInfo = value
            GDLogBLEInfo("READ sensor INFO value (arrtest): \(valueAsArr)")
        } else {
            GDLogBLEInfo("READ value from unknown charateristic: \(characteristic.debugDescription)")
        }
    }
    
    // TODO: Write-to-characterisctic-method (and getting the reply)
    internal func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error? ){
        if error != nil {
            GDLogBLEError("Error writing to config: \(error!)")
            return
        }
        GDLogBLEInfo("EARS: WRITE SUCESS \(BoseEventProcessor.dataToIntArray(data: characteristic.value!))")
        bosePeripheral?.readValue(for: boseHeadTrackingConfig!)
    }
    
    // MARK: - SERVICES DISCOVERED
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            GDLogBLEError("EARS: ERROR getting services from peripheral \(peripheral.identifier.uuidString): \(error)")
            return
        }
        guard let services = peripheral.services else {
            GDLogBLEError("EARS: didDiscover services but services is nil!")
            return
        }
        // There should be only one service, right? FDD2...
        if services.count != 1 {
            GDLogBLEInfo("EARS: Found more than one service!")
        }
        
        // Lets parse them any way...
        for service in services {
            
            if service.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE.uuidString {
                GDLogBLEInfo("EARS: Found service, discovering characteristics")
                self.boseHeadTrackingService = service
                self.bosePeripheral?.discoverCharacteristics([BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC, BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC, BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_INFO_CHARACTERISTIC], for: service)
                break
            }
        }
    }
    
    // MARK: DISCOVERED CHARATERISTICS
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            GDLogBLEError("EARS: Error getting chracteristics from service  \(service.uuid.uuidString): \(error)")
            return
        }
        guard let characteristics = service.characteristics else {
            GDLogBLEError("EARS: didDiscoverCharateristic but it is nil!")
            return
        }
        guard let boseDevice = self.bosePeripheral else {
            GDLogBLEError("EARS: connectedHeadphones is nil?")
            return
        }
        
        self.boseHeadTrackingConfig = nil
        self.boseHeadTrackingData = nil
        
        for c in characteristics {
            if c.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
                self.boseHeadTrackingConfig = c
                boseDevice.setNotifyValue(true, for: self.boseHeadTrackingConfig!)
                boseDevice.readValue(for: self.boseHeadTrackingConfig!)
                continue
            }
            if c.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
                self.boseHeadTrackingData = c
                boseDevice.setNotifyValue(true, for: self.boseHeadTrackingData!)
                //   boseDevice.readValue(for: self.boseHeadTrackingData!)
                continue
            }
            if c.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_INFO_CHARACTERISTIC.uuidString {
                self.boseHeadTrackingInfo = c
                boseDevice.readValue(for: self.boseHeadTrackingInfo!)
                continue
            }
        }
        
        if self.boseHeadTrackingData == nil || self.boseHeadTrackingConfig == nil || self.boseHeadTrackingInfo == nil {
            GDLogBLEError("EARS: ERROR! Didn't find both config AND data characteristic AND info for the (suspected) headtracking service. Continuing anyway...")
        }
    }
    
    // MARK: SUBSCR. CONFIRMATION
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?){
        if let error = error {
            GDLogBLEError("EARS: Error subscribing to charateristic \(characteristic.uuid.uuidString): \(error)")
            return
        }
        GDLogBLEInfo("EARS: Subscribing to charatersitc: \(characteristic.description)")
    }
}
