//
//  DynamicAudioEngineAssets.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

// MARK: Original Beacons

enum ClassicBeacon: String, DynamicAudioEngineAsset {
    case beatOn = "Classic_OnAxis"
    case beatOff = "Classic_OffAxis"
    
    static var selector: AssetSelector? = ClassicBeacon.defaultSelector()
    static var beatsInPhrase: Int = 2
}

enum V2Beacon: String, DynamicAudioEngineAsset {
    case center = "Current_A+"
    case offset = "Current_A"
    case side   = "Current_B"
    case behind = "Current_Behind"
    
    static var selector: AssetSelector? = V2Beacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

// MARK: Exploratory Beacons

enum TactileBeacon: String, DynamicAudioEngineAsset {
    case center = "Tactile_OnAxis"
    case offset = "Tactile_OffAxis"
    case behind = "Tactile_Behind"
    
    static var selector: AssetSelector? = TactileBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum FlareBeacon: String, DynamicAudioEngineAsset {
    case center = "Flare_A+"
    case offset = "Flare_A"
    case side   = "Flare_B"
    case behind = "Flare_Behind"
    
    static var selector: AssetSelector? = FlareBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum ShimmerBeacon: String, DynamicAudioEngineAsset {
    case center = "Shimmer_A+"
    case offset = "Shimmer_A"
    case side   = "Shimmer_B"
    case behind = "Shimmer_Behind"
    
    static var selector: AssetSelector? = ShimmerBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum PingBeacon: String, DynamicAudioEngineAsset {
    case center = "Ping_A+"
    case offset = "Ping_A"
    case side   = "Ping_B"
    case behind = "Tactile_Behind"
    
    static var selector: AssetSelector? = PingBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum DropBeacon: String, DynamicAudioEngineAsset {
    case center = "Drop_A+"
    case offset = "Drop_A"
    case behind = "Drop_Behind"
    
    static var selector: AssetSelector? = DropBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum SignalBeacon: String, DynamicAudioEngineAsset {
    case center = "Signal_A+"
    case offset = "Signal_A"
    case behind = "Drop_Behind"
    
    static var selector: AssetSelector? = SignalBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum SignalSlowBeacon: String, DynamicAudioEngineAsset {
    case center = "Signal_Slow_A+"
    case offset = "Signal_Slow_A"
    case behind = "Signal_Slow_Behind"
    
    static var selector: AssetSelector? = SignalSlowBeacon.defaultSelector()
    static let beatsInPhrase: Int = 12
}

enum SignalVerySlowBeacon: String, DynamicAudioEngineAsset {
    case center = "Signal_Very_Slow_A+"
    case offset = "Signal_Very_Slow_A"
    case behind = "Signal_Very_Slow_Behind"
    
    static var selector: AssetSelector? = SignalVerySlowBeacon.defaultSelector()
    static let beatsInPhrase: Int = 18
}

enum MalletBeacon: String, DynamicAudioEngineAsset {
    case center = "Mallet_A+"
    case offset = "Mallet_A"
    case behind = "Mallet_Behind"
    
    static var selector: AssetSelector? = MalletBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum MalletSlowBeacon: String, DynamicAudioEngineAsset {
    case center = "Mallet_Slow_A+"
    case offset = "Mallet_Slow_A"
    case behind = "Mallet_Slow_Behind"
    
    static var selector: AssetSelector? = MalletSlowBeacon.defaultSelector()
    static let beatsInPhrase: Int = 12
}

enum MalletVerySlowBeacon: String, DynamicAudioEngineAsset {
    case center = "Mallet_Very_Slow_A+"
    case offset = "Mallet_Very_Slow_A"
    case behind = "Mallet_Very_Slow_Behind"
    
    static var selector: AssetSelector? = MalletVerySlowBeacon.defaultSelector()
    static let beatsInPhrase: Int = 18
}

enum FollowTheMusicBeacon: String, DynamicAudioEngineAsset {
    case center = "FollowTheMusic_A+"
    case offset = "FollowTheMusic_A"
    case side   = "FollowTheMusic_B"
    case behind = "FollowTheMusic_Behind"
    
    static var selector: AssetSelector? = FollowTheMusicBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum WalkAMileInMyShoesBeacon: String, DynamicAudioEngineAsset {
    case center = "WalkAMileInMyShoes_A+"
    case offset = "WalkAMileInMyShoes_A"
    case side   = "WalkAMileInMyShoes_B"
    case behind = "WalkAMileInMyShoes_Behind"
    
    static var selector: AssetSelector? = WalkAMileInMyShoesBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum NoTonesPleaseBeacon: String, DynamicAudioEngineAsset {
    case center = "NoTonesPlease_A+"
    case offset = "NoTonesPlease_A"
    case side   = "NoTonesPlease_B"
    case behind = "NoTonesPlease_Behind"
    
    static var selector: AssetSelector? = NoTonesPleaseBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum SilenceIsGolden1Beacon: String, DynamicAudioEngineAsset {
    case center = "SilenceIsGolden1_A+"
    case offset = "SilenceIsGolden1_A"
    case side   = "SilenceIsGolden1_B"
    case behind = "SilenceIsGolden1_Behind"
    
    static var selector: AssetSelector? = SilenceIsGolden1Beacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum SilenceIsGolden2Beacon: String, DynamicAudioEngineAsset {
    case center = "SilenceIsGolden2_A+"
    case offset = "SilenceIsGolden2_A"
    case side   = "SilenceIsGolden2_B"
    case behind = "SilenceIsGolden2_Behind"
    
    static var selector: AssetSelector? = SilenceIsGolden2Beacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum TheNewNoiseBeacon: String, DynamicAudioEngineAsset {
    case center = "TheNewNoise_A+"
    case offset = "TheNewNoise_A"
    case side   = "TheNewNoise_B"
    case behind = "TheNewNoise_Behind"
    
    static var selector: AssetSelector? = TheNewNoiseBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum AfricaBeacon: String, DynamicAudioEngineAsset {
    case center = "Africa_A+"
    case offset = "Africa_A"
    case side   = "Africa_B"
    case behind = "Africa_Behind"
    
    static var selector: AssetSelector? = AfricaBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum NoTonesV2Beacon: String, DynamicAudioEngineAsset {
    case center = "NTPV2_A+"
    case offset = "NTPV2_A"
    case side   = "NTPV2_B"
    case behind = "NTPV2_Behind"
    
    static var selector: AssetSelector? = NoTonesV2Beacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum SoundcloudBeacon: String, DynamicAudioEngineAsset {
    case center = "Soundcloud_A+"
    case offset = "Soundcloud_A"
    case side   = "Soundcloud_B"
    case behind = "Soundcloud_Behind"
    
    static var selector: AssetSelector? = SoundcloudBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum TheNewerNoiseBeacon: String, DynamicAudioEngineAsset {
    case center = "NewerNoise_A+"
    case offset = "NewerNoise_A"
    case side   = "NewerNoise_B"
    case behind = "NewerNoise_Behind"
    
    static var selector: AssetSelector? = TheNewerNoiseBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum VolvoBeacon: String, DynamicAudioEngineAsset {
    case center = "Volvo_A+"
    case offset = "Volvo_A"
    case side   = "Volvo_B"
    case behind = "Volvo_Behind"
    
    static var selector: AssetSelector? = VolvoBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

enum Volvo2Beacon: String, DynamicAudioEngineAsset {
    case center = "Volvo2_A+"
    case offset = "Volvo2_A"
    case side   = "Volvo2_B"
    case behind = "Volvo2_Behind"
    
    static var selector: AssetSelector? = Volvo2Beacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}

// MARK: - Distance-Based Beacons

enum ProximityBeacon: String, DynamicAudioEngineAsset {
    case far = "Proximity_Far"
    case near = "Proximity_Close"
    
    static let beatsInPhrase: Int = 6
    
    static var selector: AssetSelector? = { input in
        if case .location(let user, let beacon) = input {
            guard let user = user else {
                return (.far, 0.0)
            }
            
            let distance = user.distance(from: beacon)
            
            if distance < 20.0 {
                return (.near, 1.0)
            } else if distance < 30.0 {
                return (.far, 1.0)
            } else {
                return (.far, 0.0)
            }
        }
        
        return nil
    }
    
}

// MARK: - Helper Assets

enum BeaconAccents: String, DynamicAudioEngineAsset {
    case start = "Route_Start"
    case end = "Route_End"
    
    static var selector: AssetSelector?
    static let beatsInPhrase: Int = 6
}

enum PreviewWandAsset: String, DynamicAudioEngineAsset {
    case noTarget = "2.4_roadFinder_loop_rev2_wFades"
    
    static var selector: AssetSelector?
    static var beatsInPhrase: Int = 1
}
