//
//  BoseBLEDevice.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-02-29.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
class BoseBLEDevice : NSObject {
    private let DEVICE_NAME: String = "le-bose frames"
    struct BOSE_SERVICE_CONSTANTS {
        static let CBUUID_HEADTRACKING_SERVICE: CBUUID = CBUUID(string: "FDD2")
        static let CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC: CBUUID = CBUUID(string: "5AF38AF6-000E-404B-9B46-07F77580890B")
        static let CBUUID_HEADTRACKING_DATA_CHARACTERISTIC: CBUUID = CBUUID(string: "56A72AB8-4988-4CC8-A752-FBD1D54A953D")
        static let CBUUID_HEADTRACKING_INFO_CHARACTERISTIC: CBUUID = CBUUID(string: "855CB3E7-98FF-42A6-80FC-40B32A2221C1")
    }
    let BOSE_HEADTRACKING_START_CODE: [UInt32] = [16777216, 131072, 848]
    let BOSE_HEADTRACKING_STOP_CODE: [UInt32] = [16777216, 131072, 768]
    private var isHeadtrackingStarted: Bool = false
    
    private var bosePeripheral: CBPeripheral?
    private var centralManager: CBCentralManager!
    private var queue = DispatchQueue(label: "services.soundscape.ble.ears")

    private var boseHeadTrackingService: CBService?
    private var boseHeadTrackingConfig: CBCharacteristic?
    private var boseHeadTrackingData: CBCharacteristic? 
    private var boseHeadTrackingInfo: CBCharacteristic?
    
    enum BoseConnectionState {
        case disconnected
        case disconnecting
        case connecting
        case connected
    }
    private var state: BoseConnectionState
    
    override init(){
        self.state = .disconnected
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    func currentConnectionState() -> BoseConnectionState {
        return self.state
    }
    func connectToBose(){
        
        GDLogBLEInfo("Testing 255, 17=\(twoBytesToSignedWord(255,17)) ; 10, 20 =\(twoBytesToSignedWord(10, 20))")
        
        // Scan for Bose headsets. These should offer the service FDD2 which (might) provide headtracking sensor charateristcvs
        centralManager.scanForPeripherals(withServices: [BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE])
//        centralManager.scanForPeripherals(withServices: nil)
        self.state = .connecting
    }
    func disconnect() {
        guard let device = bosePeripheral, let cm = centralManager else {return}
        self.state = .disconnecting
        cm.cancelPeripheralConnection(device)
    }
    func startHeadTracking() {
        let myData = BOSE_HEADTRACKING_START_CODE.withUnsafeBufferPointer {Data(buffer: $0)}
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = true
    }
    func stopHeadTracking() {
        var myData = BOSE_HEADTRACKING_STOP_CODE.withUnsafeBufferPointer {Data(buffer: $0)}
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = false
    }
    func isHeadTrackingStarted() -> Bool {
        return self.isHeadtrackingStarted
    }
    func writeValueToConfig(value: Data){
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
        GDLogBLEInfo("About to write: \(dataToIntArray(data: value))")
        device.writeValue(value, for: configCharacteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate Manager State

extension BoseBLEDevice: CBCentralManagerDelegate {
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        GDLogBLEInfo("EARS: BOSE BLE central manager state changed to '\(centralManager.state)'")
        switch central.state {
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
    
    
    // MARK: - Discover Peripherals, services and characteristics
      
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
        
        centralManager.connect(peripheral, options: [CBConnectPeripheralOptionEnableTransportBridgingKey : true])
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

// MARK: - PERIPHERAL DELEGATE
extension BoseBLEDevice: CBPeripheralDelegate {

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
//                boseDevice.setNotifyValue(true, for: self.boseHeadTrackingData!)
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
        
        
        
        // TODO:
        /*
            - (KLART) Skriv en manuell rutin som plockar bytes till structen (reverse byte order)
                - field 2 (normal order) verkarha 0 rakt i söder!)
            - (SKIP?) Kan data från Bose vara två float och en int32 (Float = 4byte)
            - (TEST) Testa att skriva 768 och se om det stannar dataströmmen (gör en toggle i UI)
            - Lista ut om någon av överiga fields kan vara pitch / yaw / roll och accuracy (kan det vara field6; gick från högt nummer till lågt och stabilt)
            - Hur kan vi skriva en BoseBLEDevice som är kompatibel men HeadphoneMotionManager
         */
        

        if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
//            GDLogBLEInfo("READ sensor DATA value: \(String(describing: characteristic.value?.debugDescription))")
            let valueAsArr = dataToByteArray(data: characteristic.value!)
            GDLogBLEInfo("READ sensor DATA value (arrtest): \(valueAsArr)")
            let boseData = dataToStruct1(data: characteristic.value!)
            // Test to keep only 12 bits
            let bitMask = 8191
            GDLogBLEInfo("""
                READ sensor DATA + Reverse:
                \tbyte:    \(boseData.byte1)
                \tfield 1: \(boseData.dataField1)
                \tfield 2: \(boseData.dataField2)
                \tfield 3: \(boseData.dataField3)
                \tfield 4: \(boseData.dataField4)
                \tfield 5: \(boseData.dataField5)
                \tfield 6: \(boseData.dataField6)
            """)

            /*           let boseData_reverse = dataToStruct1_reverseByteOrder(data: characteristic.value!)
            GDLogBLEInfo("""
                READ sensor DATA + Reverse:
                \tbyte:    \(boseData.byte1) \t \(boseData_reverse.byte1)
                \tfield 1: \(boseData.dataField1) \t \(boseData_reverse.dataField1)
                \tfield 2: \(boseData.dataField2) \t \(boseData_reverse.dataField2)
                \tfield 3: \(boseData.dataField3) \t \(boseData_reverse.dataField3)
                \tfield 4: \(boseData.dataField4) \t \(boseData_reverse.dataField4)
                \tfield 5: \(boseData.dataField5) \t \(boseData_reverse.dataField5)
                \tfield 6: \(boseData.dataField6) \t \(boseData_reverse.dataField6)
            """)
  */
            
        } else if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
            GDLogBLEInfo("READ sensor CONFIG value: \(String(describing: characteristic.value?.debugDescription))")
            let valueAsArr = dataToByteArray(data: characteristic.value!)
            GDLogBLEInfo("READ sensor CONFIG value (arrtest): \(valueAsArr)")

        } else if characteristic.uuid.uuidString == BOSE_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_INFO_CHARACTERISTIC.uuidString {
            GDLogBLEInfo("READ sensor INFO value: \(String(describing: characteristic.value?.debugDescription))")
        } else {
            GDLogBLEInfo("READ value from unknown charateristic: \(characteristic.debugDescription)")
        }
            
            
        /*
        let valueAsString = String(data: value, encoding: .utf8)
        let valueAsByteArray = value.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt32>(start: $0, count: value.count/MemoryLayout<UInt32>.stride))
        }
        */
    }
    
    // TODO: Write-to-characterisctic-method (and getting the reply)
    internal func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error? ){
        if error != nil {
            GDLogBLEError("Error writing to config: \(error!)")
            return
        }
        GDLogBLEInfo("EARS: WRITE SUCESS \(dataToIntArray(data: characteristic.value!))")
        bosePeripheral?.readValue(for: boseHeadTrackingConfig!)
    }
    
    
    // MARK: Convenience functions
    private func convertDataToString(data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    private func dataToIntArray(data: Data) -> [UInt32] {

            return data.withUnsafeBytes {
                Array(UnsafeBufferPointer<UInt32>(start: $0, count: data.count/MemoryLayout<UInt32>.stride))
            }

    }
    private func dataToByteArray(data: Data) -> [UInt8] {
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt8>(start: $0, count: data.count/MemoryLayout<UInt8>.stride))
        }
    }
    private func twoBytesToSignedWord(_ value1: UInt8, _ value2: UInt8) -> Int16 {
        var a: UInt16 = UInt16(value1) << 8
        var b: UInt16 = UInt16(value2)
        let val1: Int16 = Int16(bitPattern: a)
        let val2: Int16 = Int16(bitPattern: b)
        return val1 | val2
    }
    
    private func dataToStruct1(data: Data) -> BoseHeadTrackingData1 {
        let arrData = dataToByteArray(data: data)

        return BoseHeadTrackingData1(byte1: arrData[0],
                                     dataField1: twoBytesToSignedWord(arrData[1], arrData[2]),
                                     dataField2: twoBytesToSignedWord(arrData[3], arrData[4]),
                                     dataField3: twoBytesToSignedWord(arrData[5], arrData[6]),
                                     dataField4: twoBytesToSignedWord(arrData[7], arrData[8]),
                                     dataField5: twoBytesToSignedWord(arrData[9], arrData[10]),
                                     dataField6: twoBytesToSignedWord(arrData[11], arrData[12]))
    }
 /*   private func dataToStruct1_reverseByteOrder(data: Data) -> BoseHeadTrackingData1 {
        let arrData = dataToByteArray(data: data)
        
        return BoseHeadTrackingData1(byte1: arrData[0],
                                     dataField1: UInt16(data[2])*256 + UInt16(data[1]),
                                     dataField2: UInt16(data[4])*256 + UInt16(data[3]),
                                     dataField3: UInt16(data[6])*256 + UInt16(data[5]),
                                     dataField4: UInt16(data[8])*256 + UInt16(data[7]),
                                     dataField5: UInt16(data[10])*256 + UInt16(data[9]),
                                     dataField6: UInt16(data[12])*256 + UInt16(data[11]))
    }*/
    struct BoseHeadTrackingData1 {
        var byte1: UInt8
        var dataField1: Int16
        var dataField2: Int16 // Yaw (heading, 0=South, 16384=North)
        var dataField3: Int16
        var dataField4: Int16 // Pitch
        var dataField5: Int16 // Roll
        var dataField6: Int16
        
    }
}
    

