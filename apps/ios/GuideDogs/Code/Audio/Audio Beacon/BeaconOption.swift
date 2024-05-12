//
//  BeaconOption.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum BeaconOption: String, CaseIterable, Identifiable {
    case original
    case current
    case flare
    case shimmer
    case tacticle
    case ping
    case drop
    case signal
    case signalSlow
    case signalVerySlow
    case mallet
    case malletSlow
    case malletVerySlow
    case followTheMusic
    case walkAMileInMyShoes
    case noTonesPlease
    case silenceIsGolden1
    case silenceIsGolden2
    case theNewNoise
    // Update `style` (see "Beacon+Style") when adding a new
    // haptic beacon
    case wand
    case pulse
    
    var id: String {
        switch self {
        case .original: return ClassicBeacon.description
        case .current: return V2Beacon.description
        case .flare: return FlareBeacon.description
        case .shimmer: return ShimmerBeacon.description
        case .tacticle: return TactileBeacon.description
        case .ping: return PingBeacon.description
        case .drop: return DropBeacon.description
        case .signal: return SignalBeacon.description
        case .signalSlow: return SignalSlowBeacon.description
        case .signalVerySlow: return SignalVerySlowBeacon.description
        case .mallet: return MalletBeacon.description
        case .malletSlow: return MalletSlowBeacon.description
        case .malletVerySlow: return MalletVerySlowBeacon.description
        case .followTheMusic: return FollowTheMusicBeacon.description
        case .walkAMileInMyShoes: return WalkAMileInMyShoesBeacon.description
        case .noTonesPlease: return NoTonesPleaseBeacon.description
        case .silenceIsGolden1: return SilenceIsGolden1Beacon.description
        case .silenceIsGolden2: return SilenceIsGolden2Beacon.description
        case .theNewNoise: return TheNewNoiseBeacon.description
        case .wand: return HapticWandBeacon.description
        case .pulse: return HapticPulseBeacon.description
        }
    }
    
    // MARK: Initialization
    
    init?(id: String) {
        guard let beacon = BeaconOption.allCases.first(where: { $0.id == id }) else {
            return nil
        }
        
        self = beacon
    }
}
