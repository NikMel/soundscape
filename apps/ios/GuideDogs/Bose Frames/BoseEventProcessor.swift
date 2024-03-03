//
//  BoseDecodeOrientationEvent.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-02.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
class BoseEventProcessor {
    var currentSensorInfo: Data = Data([])
    struct BoseHeadTrackingData1 {
        var byte1: UInt8
        var dataField1: Int16 // Cyclic sample counter? Seems to count each sample

        /* dataFild2: Yaw with oddities
         Yaw, this one has its zero-point SOUTH. When rotating passed south, it shows a difference between east and west.
         Going from south east-ward it rolls over to 65535 and counts down; west-wards it counts up.
         Rotating towrads north it reaches 16384 (downwards coming in from east and upwards from west).
         At north it will count down again in either direction, thus it is impossible to determine if it changed direction at north or continued rotating.
         If rotating a full circle clockwise (S-W-N-E-S), it will come backing in towards south (from E) counting down to 0 and then rolling over to 65535 going back W (thus reversing the situation).
         Doing another full circle with put it back in the inital state (0 to the south counting up going W and rolling over counting down E)
         */
        var dataField2: Int16
        
        /* dataField3: Yaw with oddities
         This one has its zero-point to the NORTH. It behaves pretty much as dataField2 but with NORTH as the rollover point. Counts up rotating W and rolls over to 65535 going E...
        */
        var dataField3: Int16
        
        /* datafield4: Pitch, some oddities
         0 is leveled, but sometimes negative is up and sometimes down...
         It seems that when it has rotated (when the Yaw-fields are sort-of-reveresed) one revolution, direction is flipped!
         Rotating another revolution, it's back to normal again!
         */
        var dataField4: Int16 // Pitch
        
        /* dataField5: Roll, some oddities
         0 is leveled other that that, same oddity as with Pitch; i.e., directions get flipped when rotating...
         */
        var dataField5: Int16 // Roll
        
        /* dataField6: Accuracy/Precision
         This decreases as data is collected. Seems to floor out at 546, occasionally increasing and getting back again. Early on it can hover at a much higher value.
         Use this field to sense is the devices is calibrated
         
         */
        var dataField6: Int16 // accuracy?
    }
    struct BoseHeadTrackingData2 {
        var byte1: UInt8
        var dataField1: UInt16 // ?
        var dataField2: UInt16 // Yaw, nope rotation direction?
        var dataField3: UInt16 // Semms more likely to be Yaw with North = 0
        var dataField4: Int16 // Pitch
        var dataField5: Int16 // Roll
        var dataField6: Int16 // accuracy?
    }
    struct BoseHeadTrackingData3 {
        var byte1: UInt8
        var dataField1: UInt16 // Sample counter
        var dataField2: Int32 // Yaw
        var dataField4: Int16 // Pitch
        var dataField5: Int16 // Roll
        var dataField6: Int16 // accuracy?
    }
    // MARK: Convenience functions
    static func convertDataToString(data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    static func dataToIntArray(data: Data) -> [UInt32] {
        
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt32>(start: $0, count: data.count/MemoryLayout<UInt32>.stride))
        }
    }
    
    static func dataToYawString(_ value: Int16) -> String {
        switch value {
        case -2000...2000:
            return "S"
        case 2001...4000:
            return "SE"
        case 4000...8000:
            return "E"
        default:
            return "Dunno"
        }
    }
    static func dataToPitchString(_ value: Int16) -> String {
        if(value > -1000 && value < 1000) {
            return "Straight"
        }
        else if value <= -1000 {
            return "Looking UP"
        }
        else {
            return "Looking DOWN"
        }
    }
    static func dataToRollString(_ value: Int16) -> String {
        if(value > -500 && value < 500) {
            return "Straight"
        }
        else if value <= -500 {
            return "Leaning LEFT"
        }
        else {
            return "Leaning RIGHT"
        }
    }
    
    static func dataToByteArray(data: Data) -> [UInt8] {
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt8>(start: $0, count: data.count/MemoryLayout<UInt8>.stride))
        }
    }
    static func twoBytesToUInt16(_ value1: UInt8, _ value2: UInt8) -> UInt16 {
        let a: UInt16 = UInt16(value1) << 8
        let b: UInt16 = UInt16(value2)
        return a | b
    }
    
    static func twoBytesToSignedWord(_ value1: UInt8, _ value2: UInt8) -> Int16 {
        let a: UInt16 = UInt16(value1) << 8
        let b: UInt16 = UInt16(value2)
        let val1: Int16 = Int16(bitPattern: a)
        let val2: Int16 = Int16(bitPattern: b)
        return val1 | val2
    }
    static func fourBytesToInt32(_ value1: UInt8, _ value2: UInt8,_ value3: UInt8, _ value4: UInt8) -> Int32 {
        let a: UInt32 = UInt32(value1) << 32
        let b: UInt32 = UInt32(value2) << 16
        let c: UInt32 = UInt32(value3) << 8
        let d: UInt32 = UInt32(value4)
        let val1 = Int32(bitPattern: a)
        let val2 = Int32(bitPattern: b)
        let val3 = Int32(bitPattern: c)
        let val4 = Int32(bitPattern: d)
        
        return val1 | val2 | val3 | val4
    }
    
    static func dataToStruct1(data: Data) -> BoseHeadTrackingData1 {
        let arrData = dataToByteArray(data: data)
        
        return BoseHeadTrackingData1(byte1: arrData[0],
                                     dataField1: twoBytesToSignedWord(arrData[1], arrData[2]),
                                     dataField2: twoBytesToSignedWord(arrData[3], arrData[4]),
                                     dataField3: twoBytesToSignedWord(arrData[5], arrData[6]),
                                     dataField4: twoBytesToSignedWord(arrData[7], arrData[8]),
                                     dataField5: twoBytesToSignedWord(arrData[9], arrData[10]),
                                     dataField6: twoBytesToSignedWord(arrData[11], arrData[12]))
    }   
    static func dataToStruct2(data: Data) -> BoseHeadTrackingData2 {
        let arrData = dataToByteArray(data: data)
        
        return BoseHeadTrackingData2(byte1: arrData[0],
                                     dataField1: twoBytesToUInt16(arrData[1], arrData[2]),
                                     dataField2: twoBytesToUInt16(arrData[3], arrData[4]),
                                     dataField3: twoBytesToUInt16(arrData[5], arrData[6]),
                                     dataField4: twoBytesToSignedWord(arrData[7], arrData[8]),
                                     dataField5: twoBytesToSignedWord(arrData[9], arrData[10]),
                                     dataField6: twoBytesToSignedWord(arrData[11], arrData[12]))
    }
    static func dataToStruct3(data: Data) -> BoseHeadTrackingData3 {
        let arrData = dataToByteArray(data: data)
        
        return BoseHeadTrackingData3(byte1: arrData[0],
                                     dataField1: twoBytesToUInt16(arrData[1], arrData[2]),
                                     dataField2: fourBytesToInt32(arrData[3], arrData[4], arrData[5], arrData[6]),
                                     dataField4: twoBytesToSignedWord(arrData[7], arrData[8]),
                                     dataField5: twoBytesToSignedWord(arrData[9], arrData[10]),
                                     dataField6: twoBytesToSignedWord(arrData[11], arrData[12]))
    }

    // MARK: Eventhandler
    func onOrientationEvent(eventData: Data) {
        //            GDLogBLEInfo("READ sensor DATA value: \(String(describing: characteristic.value?.debugDescription))")
        let valueAsArr = BoseEventProcessor.dataToByteArray(data: eventData)
        GDLogBLEInfo("READ sensor DATA value (arrtest): \(valueAsArr)")

//        let yawString = BoseEventProcessor.dataToYawString(boseData.dataField2)
//        let pitchString = BoseEventProcessor.dataToPitchString(boseData.dataField4)
//        let rollString = BoseEventProcessor.dataToRollString(boseData.dataField5)
        // Test to keep only 12 bits

// Struct2
        
        let boseData = BoseEventProcessor.dataToStruct1(data: eventData)
        GDLogBLEInfo("""
            INFO: \(BoseEventProcessor.dataToByteArray(data: self.currentSensorInfo))
            READ sensor DATA + Reverse:
            \tbyte:    \(boseData.byte1)
            \tfield 1: \(boseData.dataField1)
            \tfield 2: \(boseData.dataField2)
            \tfield 3: \(boseData.dataField3)
            \tfield 4: \(BoseEventProcessor.dataToPitchString(boseData.dataField4))
            \tfield 5: \(BoseEventProcessor.dataToRollString(boseData.dataField5))
            \tfield 6: \(boseData.dataField6)
        """)

        // Struct3
/*                let boseData = BoseEventProcessor.dataToStruct3(data: eventData)
                GDLogBLEInfo("""
                    READ sensor DATA:
                    \tbyte:    \(boseData.byte1)
                    \tfield 1: \(boseData.dataField1)
                    \tfield 2: \(boseData.dataField2)
                    \tfield 4: \(BoseEventProcessor.dataToPitchString(boseData.dataField4))
                    \tfield 5: \(BoseEventProcessor.dataToRollString(boseData.dataField5))
                    \tfield 6: \(boseData.dataField6)
                """)
 */
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

    
    
    /*
     let valueAsString = String(data: value, encoding: .utf8)
     let valueAsByteArray = value.withUnsafeBytes {
     Array(UnsafeBufferPointer<UInt32>(start: $0, count: value.count/MemoryLayout<UInt32>.stride))
     }
     */
    }
}
