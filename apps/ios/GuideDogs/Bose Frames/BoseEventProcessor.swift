//
//  BoseDecodeOrientationEvent.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-02.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
class BoseEventProcessor {
    var currentSensorConfig: BoseSensorConfiguration?
    struct BoseVectorData {
        var x: Int16
        var y: Int16
        var z: Int16
        var accuracy: UInt8
    }
    private let BOSE_ACCURACY_STRINGS: [String] = ["unrealiable", "low", "medium", "high"]
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
        if(value > -500 && value < 500) {
            return "Straight"
        }
        else if value <= -500 {
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
            return "Leaning RIGHT"
        }
        else {
            return "Leaning LEFT"
        }
    }
    
    
    static func dataToStruct1(data: Data) -> BoseHeadTrackingData1 {
        let arrData = BitUtils.dataToByteArray(data: data)
        
        return BoseHeadTrackingData1(byte1: arrData[0],
                                     dataField1: BitUtils.twoBytesToInt16(arrData[1], arrData[2]),
                                     dataField2: BitUtils.twoBytesToInt16(arrData[3], arrData[4]),
                                     dataField3: BitUtils.twoBytesToInt16(arrData[5], arrData[6]),
                                     dataField4: BitUtils.twoBytesToInt16(arrData[7], arrData[8]),
                                     dataField5: BitUtils.twoBytesToInt16(arrData[9], arrData[10]),
                                     dataField6: BitUtils.twoBytesToInt16(arrData[11], arrData[12]))
    }
    static func dataToStruct2(data: Data) -> BoseHeadTrackingData2 {
        let arrData = BitUtils.dataToByteArray(data: data)
        
        return BoseHeadTrackingData2(byte1: arrData[0],
                                     dataField1: BitUtils.twoBytesToUInt16(arrData[1], arrData[2]),
                                     dataField2: BitUtils.twoBytesToUInt16(arrData[3], arrData[4]),
                                     dataField3: BitUtils.twoBytesToUInt16(arrData[5], arrData[6]),
                                     dataField4: BitUtils.twoBytesToInt16(arrData[7], arrData[8]),
                                     dataField5: BitUtils.twoBytesToInt16(arrData[9], arrData[10]),
                                     dataField6: BitUtils.twoBytesToInt16(arrData[11], arrData[12]))
    }
    static func dataToStruct3(data: Data) -> BoseHeadTrackingData3 {
        let arrData = BitUtils.dataToByteArray(data: data)
        
        return BoseHeadTrackingData3(byte1: arrData[0],
                                     dataField1: BitUtils.twoBytesToUInt16(arrData[1], arrData[2]),
                                     dataField2: BitUtils.fourBytesToInt32(arrData[3], arrData[4], arrData[5], arrData[6]),
                                     dataField4: BitUtils.twoBytesToInt16(arrData[7], arrData[8]),
                                     dataField5: BitUtils.twoBytesToInt16(arrData[9], arrData[10]),
                                     dataField6: BitUtils.twoBytesToInt16(arrData[11], arrData[12]))
    }

    private func processVectorData(vectorByteArray: [UInt8]) {
        let sensorId: UInt8 = vectorByteArray[0] // 0=Accellerometer 1=Gyroscope 2=Rotation 3=Game-rotation
        let timeStamp:UInt16 = BitUtils.twoBytesToUInt16(vectorByteArray[1], vectorByteArray[2])
        var x: Int16 = BitUtils.twoBytesToInt16(vectorByteArray[3], vectorByteArray[4])
        var y: Int16 = BitUtils.twoBytesToInt16(vectorByteArray[5], vectorByteArray[6])
        var z: Int16 = BitUtils.twoBytesToInt16(vectorByteArray[7], vectorByteArray[8])
        let accuracy: UInt8 = vectorByteArray[9]
        
        // Apply the correlation matrix
        let m = CorrectionMatrix.getMatrix()
        let e = m.getElements()
        
        let w = 1 / ( e[ 3 ] * x + e[ 7 ] * y + e[ 11 ] * z + e[ 15 ] );
        
        let xTrans = ( e[ 0 ] * x + e[ 4 ] * y + e[ 8 ] * z + e[ 12 ] ) * w
        let yTrans = ( e[ 1 ] * x + e[ 5 ] * y + e[ 9 ] * z + e[ 13 ] ) * w
        let zTrans = ( e[ 2 ] * x + e[ 6 ] * y + e[ 10 ] * z + e[ 14 ] ) * w

        /*
         m is the CorrelationMatrix
         applyMatrix4: function ( m ) {

                     var x = this.x, y = this.y, z = this.z;
                     var e = m.elements;

                     var w = 1 / ( e[ 3 ] * x + e[ 7 ] * y + e[ 11 ] * z + e[ 15 ] );

                     this.x = ( e[ 0 ] * x + e[ 4 ] * y + e[ 8 ] * z + e[ 12 ] ) * w;
                     this.y = ( e[ 1 ] * x + e[ 5 ] * y + e[ 9 ] * z + e[ 13 ] ) * w;
                     this.z = ( e[ 2 ] * x + e[ 6 ] * y + e[ 10 ] * z + e[ 14 ] ) * w;

                     return this;
         
         */

        GDLogBLEInfo("""
            \tsensorId:  \(sensorId)
            \ttimestamp: \(timeStamp)
            \tx-value:   \(xTrans) \t \(x) \t \(BoseEventProcessor.dataToRollString(xTrans))
            \ty-value:   \(yTrans) \t \(y) \t \(BoseEventProcessor.dataToPitchString(yTrans))
            \tz-value:   \(zTrans) \t \(z)
            \taccuracy:  \(BOSE_ACCURACY_STRINGS[Int(accuracy)])
        """)
    }
    
    private func processQuaternionData(quaternionByteArray: [UInt8]) {
        let sensorId: UInt8 = quaternionByteArray[0] // 0=Accellerometer 1=Gyroscope 2=Rotation 3=Game-rotation
        let timeStamp:UInt16 = BitUtils.twoBytesToUInt16(quaternionByteArray[1], quaternionByteArray[2])
        let x_raw: Int16 = BitUtils.twoBytesToInt16(quaternionByteArray[3], quaternionByteArray[4])
        let y_raw: Int16 = BitUtils.twoBytesToInt16(quaternionByteArray[5], quaternionByteArray[6])
        let z_raw: Int16 = BitUtils.twoBytesToInt16(quaternionByteArray[7], quaternionByteArray[8])
        let w_raw: Int16 = BitUtils.twoBytesToInt16(quaternionByteArray[9], quaternionByteArray[10])
        let accuracy: UInt8 = quaternionByteArray[11]
        
        let correctionQ = CorrectionQuaternion.getCorrectionQuaternion()
        var x: Double = Double(x_raw)
        var y: Double = Double(y_raw)
        var z: Double = Double(z_raw)
        var w: Double = Double(w_raw)
        // Multiply with the correction quaternion (quaternion.multiply(correctionQuaternion))
        /*
         multiply (a: quaternion, b: correctionQuaternion):
                var qax = a._x, qay = a._y, qaz = a._z, qaw = a._w;
                var qbx = b._x, qby = b._y, qbz = b._z, qbw = b._w;

                a._x = qax * qbw + qaw * qbx + qay * qbz - qaz * qby;
                a._y = qay * qbw + qaw * qby + qaz * qbx - qax * qbz;
                a._z = qaz * qbw + qaw * qbz + qax * qby - qay * qbx;
                a._w = qaw * qbw - qax * qbx - qay * qby - qaz * qbz;
         */
        let qax = Double(x), qay = Double(y), qaz = Double(z), qaw = Double(w)
        let qbx = correctionQ.x, qby = correctionQ.y, qbz = correctionQ.z, qbw = correctionQ.w;
        x = qax * qbw + qaw * qbx + qay * qbz - qaz * qby;
        y = qay * qbw + qaw * qby + qaz * qbx - qax * qbz;
        z = qaz * qbw + qaw * qbz + qax * qby - qay * qbx;
        w = qaw * qbw - qax * qbx - qay * qby - qaz * qbz;
        
        /*

          2. Calculate pitch:
                 get pitch() {
                     const {w, x, y, z} = this;

                     let sinp = 2 * (w * x + y * z);
                     let cosp = 1 - 2 * (x * x + y * y);

                     let pitch = Math.atan2(sinp, cosp) + Math.PI;

                     return (pitch > Math.PI)?
                         pitch - 2 * Math.PI :
                         pitch;
                 }
         */
        let sinp = 2 * (w*x + y*z)
        let cosp = 1 - 2 * (x * x + y * y);
        var pitch = atan2(sinp, cosp) + Double.pi;
        pitch = (pitch > Double.pi) ? pitch - 2 * Double.pi :  pitch;
        
        /*
          3. Calculate Roll:
                 get roll() {
                      const {w, x, y, z} = this;

                      let sinr = 2 * (w*y - z*x);
                      if(Math.abs(sinr) >= 1) {
                          return -(Math.sign(sinr) * Math.PI/2);
                      }
                      else {
                          return -Math.asin(sinr);
                      }
                  }
         */
        let sinr = 2 * (w*y - z*x);
        var roll: Double
        if(abs(sinr) >= 1) {
            roll = -( ((sinr < 0) ? -1 : 1) * Double.pi/2);
        }
        else {
            roll = -asin(sinr);
        }
        /*
            4. Calculate yaw:
                 get yaw() {
                     const {w, x, y, z} = this;

                     const siny = 2 * (w*z + x*y);
                     const cosy = 1 - 2 * (y*y + z*z);

                     return -Math.atan2(siny, cosy);
                 }
         */
        let siny = 2 * (w*z + x*y);
        let cosy = 1 - 2 * (y*y + z*z);

        let yaw: Double = -atan2(siny, cosy);
        
  
        GDLogBLEInfo("""
            \tsensorId:  \(sensorId)
            \ttimestamp: \(timeStamp)
            \tRoll:      \(roll*100)
            \tPitch:     \(pitch*100)
            \tYaw:       \(yaw*100)
            \taccuracy:  \(accuracy)
        """)
    }


struct CorrectionQuaternion {
    static var correctionQuaternion: CorrectionQuaternion?
    let x: Double
    let y: Double
    let z: Double
    let w: Double
        
    static func getCorrectionQuaternion() -> CorrectionQuaternion {
        if(correctionQuaternion != nil) {
            return correctionQuaternion!
        }
        var _x: Double
        var _y: Double
        var _z: Double
        var _w: Double
        
        let correctionMatrix = CorrectionMatrix.getMatrix()
        /* this = quaternion, m=correctionMatrix*/
        let te = correctionMatrix.getElements(),
            m11 = te[ 0 ], m12 = te[ 4 ], m13 = te[ 8 ],
            m21 = te[ 1 ], m22 = te[ 5 ], m23 = te[ 9 ],
            m31 = te[ 2 ], m32 = te[ 6 ], m33 = te[ 10 ],
            trace = m11 + m22 + m33, s: Double;

        if ( trace > 0 ) {
            
            s = 0.5 / sqrt( Double(trace) + 1.0 );
            
            _w = 0.25 / s;
            _x = Double( m32 - m23 ) * s;
            _y = Double( m13 - m31 ) * s;
            _z = Double( m21 - m12 ) * s;
            
        } else if ( m11 > m22 && m11 > m33 ) {
            
            s = 2.0 * sqrt( 1.0 + Double(m11 - m22 - m33 ));
            
            _w = Double( m32 - m23 ) / s;
            _x = 0.25 * s;
            _y = Double( m12 + m21 ) / s;
            _z = Double( m13 + m31 ) / s;
            
        } else if ( m22 > m33 ) {
            
            s = 2.0 * sqrt( 1.0 + Double(m22 - m11 - m33 ));
            
            _w = Double( m13 - m31 ) / s;
            _x = Double( m12 + m21 ) / s;
            _y = 0.25 * s;
            _z = Double( m23 + m32 ) / s;
            
        } else {
            
            s = 2.0 * sqrt( 1.0 + Double(m33 - m11 - m22 ));
            
            _w = Double( m21 - m12 ) / s;
            _x = Double( m13 + m31 ) / s;
            _y = Double( m23 + m32 ) / s;
            _z = 0.25 * s;
            
        }
        
        correctionQuaternion = CorrectionQuaternion(x: _x, y: _y, z: _z, w: _w)
        return correctionQuaternion!
    }
}

    // MARK: Eventhandler
    func onOrientationEvent(eventData: Data) {
        //            GDLogBLEInfo("READ sensor DATA value: \(String(describing: characteristic.value?.debugDescription))")
       let valueAsArr = BitUtils.dataToByteArray(data: eventData)
//        GDLogBLEInfo("READ sensor DATA value (arrtest): \(valueAsArr)")

        switch valueAsArr[0] {
        case self.currentSensorConfig?.accelerometerId:
            GDLogBLEInfo("Got an accellerometer data update, read 10 bytes. UNSUPPORTED: \(valueAsArr)")
            processVectorData(vectorByteArray: valueAsArr)
            return
        case self.currentSensorConfig?.gyroscopeId:
            GDLogBLEInfo("Got an gyroscope data update, read 10 bytes: \(valueAsArr)")
            // TODO: Decode Gyroscope data (x, y, z and accuracy) -> BoseVectorData
            processVectorData(vectorByteArray: valueAsArr)
            return
        case self.currentSensorConfig?.rotationId:
            GDLogBLEInfo("Got an rotation data update, read 12 bytes. UNSUPPORTED: \(valueAsArr)")
            processQuaternionData(quaternionByteArray: valueAsArr)
            return
        case self.currentSensorConfig?.gamerotationId:
            GDLogBLEInfo("Got an gyroscope data update, read 12 bytes. UNSUPPORTED: \(valueAsArr)")
            return
        default:
            GDLogBLEError("READ: Unknown sensor!")
            return
        }
    }
}


class BoseSensorConfiguration {
    // Period is in millisecond update interval. Valid intervals:    320, 160, 80, 40, 20
    let gyroscopeId:UInt8 = 0
    var gyroscopePeriod: UInt16 = 0

    let accelerometerId:UInt8 = 1
    var accelerometerPeriod: UInt16 = 0
        
    let rotationId:UInt8 = 2
    var rotationPeriod: UInt16 = 0
    
    let gamerotationId:UInt8 = 3
    var gamerotationPeriod: UInt16 = 0
    
    static func parseValue(data: Data) -> BoseSensorConfiguration {
        let byteArray: [UInt8] = BitUtils.dataToByteArray(data: data)
        var result = BoseSensorConfiguration()
        
        result.accelerometerPeriod = BitUtils.twoBytesToUInt16(byteArray[1], byteArray[2])
        result.gyroscopePeriod = BitUtils.twoBytesToUInt16(byteArray[4], byteArray[5])
        result.rotationPeriod = BitUtils.twoBytesToUInt16(byteArray[7], byteArray[8])
        result.gamerotationPeriod = BitUtils.twoBytesToUInt16(byteArray[10], byteArray[11])
        
        return result
    }
    
    private func toByteArr<T: BinaryInteger>(endian: T, count: Int) -> [UInt8] {
        var _endian = endian
        let bytePtr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](bytePtr)
    }
    private func swapEndianess(byteArr: [UInt8]) -> [UInt8] {
        return [byteArr[1], byteArr[0]]
    }
    
    
    func toConfigToData() -> Data {
        var newConfig: Data = Data()
        
        var tst = toByteArr(endian: gyroscopePeriod, count: 2)
        
        newConfig.append(contentsOf: [accelerometerId])
        newConfig.append(contentsOf: swapEndianess(byteArr: toByteArr(endian: accelerometerPeriod, count: 2)))

        newConfig.append(contentsOf: [gyroscopeId])
        newConfig.append(contentsOf: swapEndianess(byteArr: toByteArr(endian: gyroscopePeriod, count: 2)))

        newConfig.append(contentsOf: [rotationId])
        newConfig.append(contentsOf: swapEndianess(byteArr: toByteArr(endian: rotationPeriod, count: 2)))
        
        newConfig.append(contentsOf: [gamerotationId])
        newConfig.append(contentsOf: swapEndianess(byteArr: toByteArr(endian: gamerotationPeriod, count: 2)))

        GDLogBLEInfo("Encoded new config to: \(BitUtils.dataToByteArray(data: newConfig))")
        
        return newConfig
    }
}

struct CorrectionMatrix {
    static var matrix: CorrectionMatrix?
    private var elements: [Int16]
    
    func getElements() -> [Int16] {
        return elements
    }
    static func getMatrix() -> CorrectionMatrix {
        if(matrix != nil) {
            return matrix!
        }

        var _matrix: CorrectionMatrix = CorrectionMatrix(elements: [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ])

        // Extract basis
/*      I think this one was wrong...
        var vecX: [Int16] = [_matrix.elements[0], _matrix.elements[4], _matrix.elements[8]]
        var vecY: [Int16] = [_matrix.elements[1], _matrix.elements[5], _matrix.elements[9]]
        var vecZ: [Int16] = [_matrix.elements[2], _matrix.elements[6], _matrix.elements[10]]
  */
        var vecX: [Int16] = [_matrix.elements[0], _matrix.elements[1], _matrix.elements[2]]
        var vecY: [Int16] = [_matrix.elements[4], _matrix.elements[5], _matrix.elements[6]]
        var vecZ: [Int16] = [_matrix.elements[8], _matrix.elements[9], _matrix.elements[10]]
        
        // Multiply with reflection vector
        let reflectionZ: [Int16] = [1, 1, -1]
        vecX[0] *= reflectionZ[0]
        vecX[1] *= reflectionZ[1]
        vecX[2] *= reflectionZ[2]
        
        vecY[0] *= reflectionZ[0]
        vecY[1] *= reflectionZ[1]
        vecY[2] *= reflectionZ[2]
        
        vecZ[0] *= reflectionZ[0]
        vecZ[1] *= reflectionZ[1]
        vecZ[2] *= reflectionZ[2]
                 
        // MakeBasis
        // Row 1
        _matrix.elements[0] = vecX[0]
        _matrix.elements[1] = vecY[0]
        _matrix.elements[2] = vecZ[0]
        _matrix.elements[3] = 0
        // Row 2
        _matrix.elements[4] = vecX[1]
        _matrix.elements[5] = vecY[1]
        _matrix.elements[6] = vecZ[1]
        _matrix.elements[7] = 0
        // Row 3
        _matrix.elements[8] = vecX[2]
        _matrix.elements[9] = vecY[2]
        _matrix.elements[10] = vecZ[2]
        _matrix.elements[11] = 0
        // Row 4
        _matrix.elements[12] = 0
        _matrix.elements[13] = 0
        _matrix.elements[14] = 0
        _matrix.elements[15] = 1

        matrix = _matrix
        return matrix!
    }
}


class BitUtils {
    
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
    
    static func twoBytesToInt16(_ value1: UInt8, _ value2: UInt8) -> Int16 {
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
}

