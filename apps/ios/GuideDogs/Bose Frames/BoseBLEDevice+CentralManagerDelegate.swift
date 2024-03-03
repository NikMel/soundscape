//
//  BoseConnectionDelegate.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-02.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
extension BoseBLEDevice: CBCentralManagerDelegate {
    
    // MARK: CentralManagerState UPDATE
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        GDLogBLEInfo("EARS: BOSE BLE central manager state changed to '\(centralManager.state)'")
        switch centralManager.state {
        case .resetting:
            GDLogBLEInfo("EARS: Bluetooth connection is resetting with the system...")
        case .unsupported:
            GDLogBLEInfo("EARS: Bluetooth connection is not supported")
        case .unauthorized:
            GDLogBLEInfo("EARS: Application is not authorized to use BLE, or something")
        case .poweredOff:
            GDLogBLEInfo("EARS: Bluetooth is currently powered off")
        case .poweredOn:
            GDLogBLEInfo("EARS: Bluetooth is currently powered on, doing some magic")
            let matchingOpts = [CBConnectionEventMatchingOption.serviceUUIDs: [BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE.uuidString]]
            centralManager.registerForConnectionEvents(options: matchingOpts)
            if(self.state == .connecting) {
                centralManager.scanForPeripherals(withServices: [BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE])
            }

        case .unknown:
            GDLogBLEInfo("EARS: BLE state is 'unknown' :/")
        default:
            GDLogBLEInfo("EARS: Hit an previuosly unknown BLE state, apparently: '\(central.state)'")
        }
    }
        
      
    // MARK: Peripheral DISCOVERED
    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        GDLogBLEVerbose("EARS: Did discover to \(peripheral.identifier) (\(peripheral.name ?? "Unnamed Peripheral"))")
        
        // If we aren't scanning anymore, then ignore any further peripherals that are delivered
        guard centralManager.isScanning else {
            GDLogBLEInfo("EARS: Discovered deveice, but has stopped scanning. Ignoring")
            return
        }
        
        let id = peripheral.identifier
        let name = peripheral.name?.lowercased() ?? "unknown"
        
        GDLogBLEInfo("Found: '\(name)', assuming its the Bose headphones as we are scanning specifically for Bose, or could we scan the Announcement data for details: \n \(debugPrintAdvertismentData(periferal: peripheral, advData: advertisementData))")
        
        centralManager.stopScan()
        self.state = .connecting
        bosePeripheral = peripheral
        bosePeripheral?.delegate = self
        
        centralManager.connect(peripheral, options: [CBConnectPeripheralOptionEnableTransportBridgingKey : false])
    }
    
    // MARK: Peripheral CONNECTED
    internal func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        GDLogBLEInfo("EARS: Did connect to \(peripheral.identifier) (\(peripheral.name ?? "Unnamed Peripheral"))")
        guard self.state == .connecting else {
            GDLogBLEError("EAR:S Received a connect event, but was not connecting!")
            return
        }
        
        self.bosePeripheral = peripheral
        self.bosePeripheral!.delegate = self
        self.state = .connected
        self.bosePeripheral!.discoverServices([BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE])
    }
    // MARK: CONNECT FAILED
    internal func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        GDLogBLEError("EARS: Failed to connect to \(peripheral.name ?? "Unnamed peripheral") (\(peripheral.identifier))")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    // MARK: DISCONNECT
    internal func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        GDLogBLEVerbose("EARS: Disconnected from \(peripheral.name ?? "Unnamed peripheral") (\(peripheral.identifier))")
        centralManager.cancelPeripheralConnection(peripheral)
        self.state = .disconnected
        self.bosePeripheral = nil
        self.boseHeadTrackingService = nil
        self.boseHeadTrackingConfig = nil
        self.boseHeadTrackingData = nil
    }
    
    
   
    // MARK: Debug methods
    
    // Debug method to generate a nicer string rep of the advertisment data
    private func debugPrintAdvertismentData(periferal: CBPeripheral, advData: [String: Any]) -> String {
        var debugAdvData: String
        var localName: String // CBAdvertisementDataLocalNameKey
        var manufacturerData: NSData // CBAdvertisementDataManufacturerDataKey
        var serviceData: [CBUUID : NSData] // CBAdvertisementDataServiceDataKey
        var serviceUUIDArray: [CBUUID] // CBAdvertisementDataServiceUUIDsKey
        var serviceUUIDsString: String = ""
        var overflowServiceUUIDs: [CBUUID] // CBAdvertisementDataOverflowServiceUUIDsKey
        var isConnectableOpt: Bool? //CBAdvertisementDataIsConnectable, Bool in an NSNumber
        var isConnectableString: String
        var solicitedServiceUUIDs: [CBUUID] // CBAdvertisementDataSolicitedServiceUUIDsKey
        
        
        
        localName = advData[CBAdvertisementDataLocalNameKey] as? String ?? "missing"
        manufacturerData = advData[CBAdvertisementDataManufacturerDataKey] as? NSData ?? NSData()
        serviceData = advData[CBAdvertisementDataServiceDataKey] as? [CBUUID:NSData] ?? [:]
        serviceUUIDArray = advData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        for uuid in serviceUUIDArray {
            serviceUUIDsString += "\t\t\(uuid.uuidString) : \(serviceData[uuid]?.description ?? "missing service data")"
            GDLogBLEInfo("Found service: \(uuid.uuidString)")
        }
        overflowServiceUUIDs = advData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []
        solicitedServiceUUIDs = advData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] ?? []
        isConnectableOpt = advData[CBAdvertisementDataIsConnectable] as? Bool ?? nil
        if isConnectableOpt != nil {
            if isConnectableOpt! {
                isConnectableString = "true"
            } else {
                isConnectableString = "false"
            }
        } else  {
            isConnectableString = "nil"
        }
        
        
        
        debugAdvData = """
            EARS: Discovered \(periferal.name ?? "unknown"), Advertiment data:
            \tlocalname: '\(localName)'
            \tmanufacturerData (descr): '\(manufacturerData.description)'
            \tserviceUUIDs: '\(serviceUUIDsString)'
            \tconnectable: '\(isConnectableString)'
            """
        
        return debugAdvData
    }
    
}
