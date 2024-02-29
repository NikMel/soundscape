//
//  SonyBLEDevice.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-02-22.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
class SonyBLEDevice : NSObject {
    private let DEVICE_NAME: String = "le-bose frames"//"le_linkbuds" //
    private var discoveredDevices: Set<UUID> = []
//    private var connectedDevices: [CBPeripheral] = []
    private var centralManager: CBCentralManager!
    private var queue = DispatchQueue(label: "services.soundscape.ble.ears")
    private var pendingConnectHeadPhones: CBPeripheral?
    private var connectedHeadPhones: CBPeripheral?
    private var isConnecting: Bool
    
    class MyDescriptor{
        var uuid: CBUUID
        var description: String
        var debugString: String
        var extraInfo: String
        var value: Any
        init(uuid: CBUUID, description: String, debugString: String, extraInfo: String, value: Any) {
            self.uuid = uuid
            self.description = description
            self.debugString = debugString
            self.extraInfo = extraInfo
            self.value = value
        }
        
    }
    class MyCharacteristic {
        var descriptors: [String:MyDescriptor] // Key = uuidString for the descriptor
        var isWritable: Bool
        var isWriteAndFogetable: Bool
        var isReadable: Bool
        var canNotify: Bool
        var canBroadcast: Bool
        var uuid: CBUUID
        var description: String
        var value: Data

        init(uuid: CBUUID, isWritable: Bool, isWriteAndFogetable: Bool, isReadable: Bool, canNotify: Bool, canBroadcast: Bool, description: String, value: Data) {
            self.uuid = uuid
            self.isWritable = isWritable
            self.isWriteAndFogetable = isWriteAndFogetable
            self.isReadable = isReadable
            self.canNotify = canNotify
            self.canBroadcast = canBroadcast
            self.description = description
            self.value = value
            self.descriptors = [:]
        }
        
    }
    class MyService {
        var charateristics: [String:MyCharacteristic] // key = uuidString for the charateristic
        var isPrimary: Bool
        var cbuuid: CBUUID
        var description: String
        init(isPrimary: Bool, cbuuid: CBUUID, description: String) {
            self.charateristics = [:]
            self.isPrimary = isPrimary
            self.cbuuid = cbuuid
            self.description = description
        }
    }
    var sonyServices: [String: MyService] = [:]
    
    override init(){
        isConnecting = false
        super.init()

        centralManager = CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    deinit {
        connectedHeadPhones = nil
        pendingConnectHeadPhones = nil
        centralManager = nil
        GDLogBLEInfo("EARS: SonyBLEDevice DE-INIT")
    }
    func scanBLEDevices() {
//        AppContext.shared.bleManager.startScan(for: SonyBLEDevice.self, delegate: self)
        //AppContext.shared.bleManager.EARS_scanForAllBLEDevices(delegate: self)
        guard centralManager.state == .poweredOn else {
            GDLogBLEInfo("EARS: Not powered on...")
            isConnecting = true
            return
        }
        
        GDLogBLEInfo("EARS: About to scan for peripherals")
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        GDLogBLEInfo("EARS: Existing scanBLEDevices...")
        isConnecting = false
        //centralManager.scanForPeripherals(withServices: [CBUUID(string: "180A")], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

    }
    func disconnect() {
        guard let device = connectedHeadPhones, let cm = centralManager else {return}
        
        cm.cancelPeripheralConnection(device)
    }
}

// MARK: - CBManagerCentral State delegate
extension SonyBLEDevice: CBCentralManagerDelegate {
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        GDLogBLEInfo("EARS: BLE central manager state changed to '\(centralManager.state)'. Ignoring...")
        if(isConnecting) {
            self.scanBLEDevices()
        }
    }
    
    
    // MARK: - PERIPHERAL discover, connect, disconnect

    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        //GDLogBLEVerbose("EARS: Did discover to \(peripheral.identifier) (\(peripheral.name ?? "Unnamed Peripheral"))")
        
        // If we aren't scanning anymore, then ignore any further peripherals that are delivered
        guard centralManager.isScanning else {
            return
        }
        
        let id = peripheral.identifier
        let name = peripheral.name?.lowercased() ?? "unknown"
GDLogBLEInfo("Found: '\(name)'")
        // AirPods, connect and stop scanning...
       /* if name.contains("airpod") {
            GDLogBLEInfo("EARS: FOUND headphones (Airpods). Stopping scan and connecting!")
            centralManager.stopScan()
            
            pendingConnectHeadPhones = peripheral
            pendingConnectHeadPhones!.delegate = self
            debugPrintAdvertismentData(periferal: peripheral, advData: advertisementData)
            centralManager.connect(pendingConnectHeadPhones!)
            return
        }*/

        // SONY Linkbuds
        if name == DEVICE_NAME {
            GDLogBLEInfo("EARS: FOUND headphones \(name). Stopping scan and connecting!")
            centralManager.stopScan()
            
            pendingConnectHeadPhones = peripheral
            pendingConnectHeadPhones!.delegate = self
            debugPrintAdvertismentData(periferal: peripheral, advData: advertisementData)
            sonyServices = [:]
            centralManager.connect(pendingConnectHeadPhones!, options: [CBConnectPeripheralOptionEnableTransportBridgingKey : true])
            
            return
        }
        // Nickes Sony WH-1000XM3
 /*       if id.uuidString == "31E97827-C250-B26C-EDE2-14549A8FB607" {
            GDLogBLEInfo("EARS: FOUND headphones (Sony WH-1000XM3). Stopping scan and connecting!")
            centralManager.stopScan()
            
            pendingConnectHeadPhones = peripheral
            pendingConnectHeadPhones!.delegate = self
            centralManager.connect(pendingConnectHeadPhones!)
            return
        }
*/
    }
    private func convertDataToString(data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }    
    
    private func debugPrintAdvertismentData(periferal: CBPeripheral, advData: [String: Any]){
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
        
        GDLogBLEInfo(debugAdvData)
        }
    
    
    internal func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        GDLogBLEInfo("EARS: Did connect to \(peripheral.identifier) (\(peripheral.name ?? "Unnamed Peripheral"))")
        
        connectedHeadPhones = peripheral
        connectedHeadPhones!.delegate = self
        pendingConnectHeadPhones = nil
        connectedHeadPhones!.discoverServices(nil)
        
    }
    
    internal func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        GDLogBLEError("EARS: Failed to connect to \(peripheral.name ?? "Unnamed peripheral") (\(peripheral.identifier))")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    internal func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        GDLogBLEVerbose("EARS: Disconnected from \(peripheral.name ?? "Unnamed peripheral") (\(peripheral.identifier))")
        centralManager.cancelPeripheralConnection(peripheral)
        printOutPeripheralServices(services: sonyServices)
    }
    private func dataToString(data: Data) -> String {
        return String(data: data, encoding: .utf8) ?? "<nil>"
    }
    private func dataToIntArray(data: Data) -> [UInt32] {
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt32>(start: $0, count: data.count/MemoryLayout<UInt32>.stride))
        }
    }
    internal func printOutPeripheralServices(services: [String:MyService]){
        var debugOutput: String
        var debugServiceList: String = "\nCBUUID\tPrimary\tDesciription\n"
        var debugCharateristicsList: String = "\nServiceId\tCBUUID\tBroadcast\tNotify\tRead\tWrite\tWwoR\tDescription\tValue(Str)\tValue([UInt32])\n"
        var debugDescriptorsList: String = "\nServiceId\tCharID\tCBUUID\tType\tValue\tDescription\tDebugString\n"
        
        debugOutput = "Discovered Services:"
        for s in sonyServices.values {
            debugOutput += "SERVICE: \(s.cbuuid.uuidString) Primary: \(s.isPrimary) Descr: '\(s.description)'\n"
            
            debugServiceList += "\(s.cbuuid.uuidString)\t\(s.isPrimary)\t\(s.description)\n"
            
            for char in s.charateristics.values {
                debugOutput += "\tCHARACTERISTIC: Broadcast: \(char.canBroadcast) Notify: \(char.canNotify) Read: \(char.isReadable) Write: \(char.isWritable) WriteAndForg: \(char.isWriteAndFogetable) Descr: '\(char.description)'\n"
                debugCharateristicsList += "\(s.cbuuid.uuidString)\t\(char.uuid.uuidString)\t\(char.canBroadcast)\t\(char.canNotify)\t\(char.isReadable)\t\(char.isWritable)\t\(char.isWriteAndFogetable)\t\(char.description)\t\(dataToString(data: char.value))\t\(dataToIntArray(data: char.value))\n"
                
                
                for descr  in char.descriptors.values {
                    debugOutput += "\t\tDESCRIPTOR: \(descr.uuid.uuidString) (\(descr.extraInfo) Value: '\(descr.value)' Descr: '\(descr.description)' Debug: \(descr.debugString)\n"
                    debugDescriptorsList += "\(s.cbuuid.uuidString)\t\(char.uuid.uuidString)\t\(descr.uuid.uuidString)\t\(descr.extraInfo)\t\(descr.value)\t\(descr.description)\t\(descr.debugString)\n"
                }
            }
        }
        GDLogBLEInfo(debugOutput)
        GDLogBLEInfo("---------------SERVICES------------\n\(debugServiceList)")
        GDLogBLEInfo("---------------CHARATERISTICS------\n\(debugCharateristicsList)")
        GDLogBLEInfo("---------------DESCRIPTORS---------\n\(debugDescriptorsList)")
        
    }
}




extension SonyBLEDevice: CBPeripheralDelegate {
    // MARK: - SERVICES discover
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            GDLogBLEError("EARS: ERROR getting services from peripheral \(peripheral.identifier.uuidString): \(error)")
            return
        }
        guard let services = peripheral.services else {
            GDLogBLEError("EARS: didDiscover services but services is nil!")
            return
        }
        // GDLogBLEInfo("  EARS: Discovered services for \(peripheral.name ?? "unknown"), services discovered: \(services.count)")
        
        for service in services {
            //GDLogBLEInfo("  EARS: Discovering characteristics for service \(service.uuid.uuidString) \(service.description)")
            var serv = MyService(isPrimary: service.isPrimary, cbuuid: service.uuid, description: service.description)
            sonyServices[service.uuid.uuidString] = serv
            connectedHeadPhones!.discoverCharacteristics(nil, for: service)
        }
        //        GDLogBLEInfo("  EARS: Done with discovering services for \(peripheral.name ?? "unknown")")
    }
    
    // MARK: - CHARACTERISTICS
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            GDLogBLEError("EARS: Error getting chracteristics from service  \(service.uuid.uuidString): \(error)")
            return
        }
        guard let characteristics = service.characteristics else {
            GDLogBLEError("EARS: didDiscoverCharateristic but it is nil!")
            return
        }
        guard let connectedHeadPhones = connectedHeadPhones else {
            GDLogBLEError("EARS: connectedHeadphones is nil?")
            return
        }
        
        
        var setOfWritableCharacteristics: Set<CBUUID> = Set()
        var setOfWritableWOResponseCharacteristics: Set<CBUUID> = Set()
        var setOfReadableCharacteristics: Set<CBUUID> = Set()
        var setOfSubscribableCharacteristics: Set<CBUUID> = Set()
        for c in characteristics {
        
            var myChar = MyCharacteristic(
                uuid: c.uuid,
                isWritable: c.properties.contains(.write),
                isWriteAndFogetable: c.properties.contains(.writeWithoutResponse),
                isReadable: c.properties.contains(.read),
                canNotify: c.properties.contains(.notify),
                canBroadcast: c.properties.contains(.broadcast),
                description: c.description,
                value: Data()
            )
            sonyServices[service.uuid.uuidString]?.charateristics[c.uuid.uuidString] = myChar
            
            
            if c.properties.contains(.read) {
                setOfReadableCharacteristics.insert(c.uuid)
                connectedHeadPhones.readValue(for: c)
            }
            if c.properties.contains(.write) {
                setOfWritableCharacteristics.insert(c.uuid)

            }
            if c.properties.contains(.writeWithoutResponse) {
                setOfWritableWOResponseCharacteristics.insert(c.uuid)
            }
            if c.properties.contains(.notify) {
                setOfSubscribableCharacteristics.insert(c.uuid)
                connectedHeadPhones.setNotifyValue(true, for: c)
            }
            //            GDLogBLEInfo("      EARS: Discovering descriptors for characteristic \(c.uuid.uuidString), \(c.debugDescription)")
            connectedHeadPhones.discoverDescriptors(for: c)
        }
        GDLogBLEInfo("""
                    \n\t\tEARS: Discovered charactersitics for service '\(service.uuid.uuidString)' (count\(characteristics.count)):
                    \t\t\tReadable: \(setOfReadableCharacteristics)
                    \t\t\tWritable: \(setOfWritableCharacteristics)
                    \t\t\tWrite wo resp: \(setOfWritableWOResponseCharacteristics)
                    \t\t\tSubscr: \(setOfSubscribableCharacteristics)
                    """)
        
        // Consider storing important characteristics internally for easy access and equivalency checks later.
        // From here, can read/write to characteristics or subscribe to notifications as desired.
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?){
        if let error = error {
            
            GDLogBLEError("EARS: Error subscribing to charateristic \(characteristic.uuid.uuidString): \(error)")
            return
        }
               GDLogBLEInfo("      EARS: Subscribing to charatersitc: \(characteristic.uuid.uuidString)")
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        if let error = error {
            GDLogBLEError("EARS: Error reading value from charateristic \(characteristic.uuid.uuidString): \(error)")
            return
        }
        guard let value = characteristic.value else {
            GDLogBLEInfo("      EARS: Read value from CHARACTERISTIC \(characteristic.uuid.uuidString) but it was nil")
            return
        }
        
        sonyServices[characteristic.service!.uuid.uuidString]?.charateristics[characteristic.uuid.uuidString]?.value = value
        
        let dataDescription = value.debugDescription
        let dataMirrorDescription = value.customMirror.description
        let valueAsString = String(data: value, encoding: .utf8)
        let valueAsByteArray = value.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt32>(start: $0, count: value.count/MemoryLayout<UInt32>.stride))
        }
        
        let readDebugOutput =
                            """
                            \n\t\t\tEARS: Read CHARACTERISTIC \(characteristic.uuid.uuidString):
                            \t\t\t\tData descr: '\(dataDescription)'
                            \t\t\t\tData mirror:'\(dataMirrorDescription)'
                            \t\t\t\tValue str:  '\(valueAsString ?? "<noval>")'
                            \t\t\t\tValue arr:  '\(valueAsByteArray)'
                            """
        GDLogBLEInfo(readDebugOutput)
    }
    
    
    // MARK: - DESCRIPTORS
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?){
        if let error = error {
            
            GDLogBLEError("EARS: Error discovering descriptor for charateristic \(characteristic.uuid.uuidString): \(error)")
            return
        }
        guard let descriptors = characteristic.descriptors else {
            GDLogBLEError("EARS: didDiscoverDescriptors but it is nil!")
            return
        }
        guard let connectedHeadPhones = connectedHeadPhones else {
            GDLogBLEError("EARS: connectedHeadphones is nil?")
            return
        }
        
        var debugString = ""
        for d in descriptors {
            let myDescriptor = MyDescriptor(uuid: d.uuid, description: d.description, debugString: d.debugDescription, extraInfo: descriptorUUIDToDescriptorName(uuid: d.uuid), value: d.value ?? "missing")
            switch d.uuid.uuidString {
            case CBUUIDCharacteristicExtendedPropertiesString:
                debugString += "\t\t\t\tHas extended property"

            case CBUUIDCharacteristicUserDescriptionString:
                debugString += "\t\t\t\tHas user description"

            case CBUUIDClientCharacteristicConfigurationString:
                debugString += "\t\t\t\tHas client config"

            case CBUUIDServerCharacteristicConfigurationString:
                debugString += "\t\t\t\tHas server config"

            case CBUUIDCharacteristicFormatString:
                debugString += "\t\t\t\tHas format"

            case CBUUIDCharacteristicAggregateFormatString:
                debugString += "\t\t\t\tHas aggregate format"

            default:
                debugString += "\t\t\t\tHas CUSTOM descr (\(d.uuid.uuidString))"
            }
            
            sonyServices[characteristic.service!.uuid.uuidString]?
                .charateristics[characteristic.uuid.uuidString]!
                .descriptors[d.uuid.uuidString] = myDescriptor
            
            GDLogBLEInfo("\n\t\t\tEARS: Discovered DESCRIPTORS for characterstic '\(characteristic.uuid.uuidString)', count: \(descriptors.count):\n\(debugString)")
            connectedHeadPhones.readValue(for: d)
        }
        
    }
    
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?){
        if let error = error {
            GDLogBLEError("EARS: Error reading value from descriptor \(descriptor.uuid.uuidString): \(error)")
            return
        }
        guard let value = descriptor.value else {
            GDLogBLEInfo("              EARS: Read value from DESCRIPTOR \(descriptor.uuid.uuidString) but it was nil")
            return
        }
        var debugString = ""
        var myDescr = sonyServices[(descriptor.characteristic!.service?.uuid.uuidString)!]!
            .charateristics[descriptor.characteristic!.uuid.uuidString]?.descriptors[descriptor.uuid.uuidString]
    
        switch descriptor.uuid.uuidString {
        case CBUUIDCharacteristicExtendedPropertiesString, CBUUIDClientCharacteristicConfigurationString, CBUUIDServerCharacteristicConfigurationString:
            // Value is NSNumber
            let number = value as? NSNumber
            debugString += "\t\t\t\t\(descriptorUUIDToDescriptorName(uuid: descriptor.uuid)) = '\(number ?? -1)'\n"
            myDescr!.value = number as Any
            
        case CBUUIDCharacteristicUserDescriptionString, CBUUIDCharacteristicAggregateFormatString:
            // Value is NSString
            let str = value as? NSString
            debugString += "\t\t\t\t\(descriptorUUIDToDescriptorName(uuid: descriptor.uuid)) = '\(str ?? "could not convert")'\n"
            myDescr!.value = str as Any
            
        case CBUUIDCharacteristicFormatString:
            // Value is NSData
            let data = value as? NSData
            debugString += "\t\t\t\t\(descriptorUUIDToDescriptorName(uuid: descriptor.uuid)) = '\(data.debugDescription)'\n"
            myDescr!.value = data as Any
            
        default:
            debugString += "\t\t\t\t\(descriptorUUIDToDescriptorName(uuid: descriptor.uuid)) = '\(value)')\n"
            myDescr!.value = value as Any
        }
        GDLogBLEInfo("\n\t\t\tEARS: READ DESCRIPTOR for Charateristic \(descriptor.characteristic?.uuid.uuidString ?? "unknown"):\n\(debugString)")
    }
    
    internal func descriptorUUIDToDescriptorName(uuid: CBUUID) -> String {
        switch uuid.uuidString {
        case CBUUIDCharacteristicExtendedPropertiesString:
            return "ExtendedProperty"
        case CBUUIDCharacteristicUserDescriptionString:
            return "UserDescription"
        case CBUUIDClientCharacteristicConfigurationString:
            return "ClientConfig"
        case CBUUIDServerCharacteristicConfigurationString:
            return "ServerConfig"
        case CBUUIDCharacteristicFormatString:
            return "FormatString"
        case CBUUIDCharacteristicAggregateFormatString:
            return "Aggregate"
        default:
            return "Custom"
        }
        
    }
}

/*
class SonyBLEDevice: BaseBLEDevice {
 override class var services: [BLEDeviceService.Type] {
        return []
    }
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: BLEDeviceType.headset, delegate: delegate)
    }


}
*/
