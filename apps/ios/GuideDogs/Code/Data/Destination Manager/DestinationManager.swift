//
//  DestinationManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import AVFoundation
import CoreLocation

extension Notification.Name {
    static let destinationChanged = Notification.Name("GDADestinationChanged")
    static let destinationAudioChanged = Notification.Name("GDADestinationAudioChanged")
    static let enableDestinationGeofence = Notification.Name("GDAEnableDestinationGeofence")
    static let disableDestinationGeofence = Notification.Name("GDADisableDestinationGeofence")
    static let destinationGeofenceDidTrigger = Notification.Name("GDADestinationGeofenceDidTrigger")
    static let beaconInBoundsDidChange = Notification.Name("GDABeaconInBoundsDidChange")
    static let cadenceDidChange: Notification.Name = Notification.Name("GDACadenceDidChange")
    static let speedDidChange: Notification.Name = Notification.Name("GDASpeedDidChange")

}

enum DestinationManagerError: Error {
    case referenceEntityDoesNotExist
}





class DestinationManager: DestinationManagerProtocol {
    
    // MARK: Notification Keys
    
    struct Keys {
        static let isAudioEnabled = "GDADestinationAudioIsEnabled"
        static let wasAudioEnabled = "GDADestinationAudioWasEnabled"
        static let geofenceDidEnter = "GDADestinationGeofenceDidEnterKey"
        static let destinationKey = "DestinationReferenceKey"
        static let isBeaconInBounds = "IsBeaconInBounds"
    }
    
    // MARK: Args for starting beacons
    
    private struct BeaconArgs {
        let loc: CLLocation
        let heading: Heading
        var startMelody: Bool
        var endMelody: Bool
    }

    private enum PaceState {
        case onPace
        case speedingUp
        case slowingDown
    }

    private var lastPaceState: PaceState = .onPace

    
    // MARK: Properties
    
    private(set) var destinationKey: String? {
        get {
            return UserDefaults.standard.value(forKey: DestinationManager.Keys.destinationKey) as? String
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DestinationManager.Keys.destinationKey)
        }
    }
    
    var isDestinationSet: Bool {
        return destinationKey != nil
    }
    
    var destination: ReferenceEntity? {
        guard let destinationKey = self.destinationKey else {
            return nil
        }
        
        return SpatialDataCache.referenceEntityByKey(destinationKey)
    }

    // All continuous audio should be disabled on launch
    var isAudioEnabled: Bool {
        return beaconPlayerId != nil || hapticBeacon != nil
    }
    
    private var beaconClosestLocation: CLLocation?
    private var temporaryBeaconClosestLocation: CLLocation?
    private var isGeofenceEnabled: Bool = true
    private var isWithinGeofence: Bool = false
    
    private weak var audioEngine: AudioEngineProtocol!
    
    private var finishBeaconPlayerOnRemove: Bool = false
    private var _beaconPlayerId: AudioPlayerIdentifier? {
        didSet {
            // Make sure there was a previous value and it doesn't equal the new value
            guard let oldID = oldValue, oldID != _beaconPlayerId else {
                return
            }
            
            if destinationKey != nil && !finishBeaconPlayerOnRemove {
                // The beacon was just muted - stop the audio without the end melody
                audioEngine.stop(oldID)
            } else {
                // Otherwise, the beacon was removed. Allow the end melody to play if one exists
                audioEngine.finish(dynamicPlayerId: oldID)
            }
            
            if _beaconPlayerId == nil {
                isCurrentBeaconAsyncFinishable = false
            }
        }
    }
    
    var beaconPlayerId: AudioPlayerIdentifier? {
        get {
            return _beaconPlayerId ?? hapticBeacon?.beacon
        }
    }
    
    private(set) var proximityBeaconPlayerId: AudioPlayerIdentifier? {
        didSet {
            // Make sure there was a previous value and it doesn't equal the new value
            guard let oldID = oldValue, oldID != proximityBeaconPlayerId else {
                return
            }
            
            if destinationKey != nil {
                // The beacon was just muted - stop the audio without the end melody
                audioEngine.stop(oldID)
            } else {
                // Otherwise, the beacon was removed. Allow the end melody to play if one exists
                audioEngine.finish(dynamicPlayerId: oldID)
            }
        }
    }
    
    private var hapticBeacon: HapticBeacon?
    
    private var didInterruptBeacon = false
    private let collectionHeading: Heading
    
    private(set) var isBeaconInBounds: Bool = false {
        didSet {
            guard oldValue != isBeaconInBounds else {
                return
            }
            
            let name = Notification.Name.beaconInBoundsDidChange
            
            let userInfo = [
                Keys.isBeaconInBounds: isBeaconInBounds
            ]
            
            NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
        }
    }

    // MARK: ETA
    private(set) var destinationETA: Double? // ETA in seconds
    private(set) var targetTime: Date? // Target time for reaching the destination


    private var distanceTraveled: CLLocationDistance = 0.0
    private var startLocation: CLLocation?
    private let distanceThreshold: CLLocationDistance = 2.0 // Minimum distance to trigger notification
    private var stepTracker: StepTracker?
    
    private(set) var isCurrentBeaconAsyncFinishable: Bool = false
    
    private var appDidInitialize = false

    // MARK: Initialization
    
    init(userLocation: CLLocation? = nil, audioEngine engine: AudioEngineProtocol, collectionHeading: Heading) {
        self.collectionHeading = collectionHeading
        
        audioEngine = engine
        
        // Verify that destination exists
        if destinationKey != nil && destination == nil {
            destinationKey = nil
        }
        
        // If the current destination is temp and doesn't have a name, remove it (it was from the scavenger hunt)
        if let destination = destination, destination.isTemp, destination.name == RouteGuidance.name {
            do {
                try clearDestination(logContext: "startup")
            } catch {
                GDLogAppError("Failed to clear temp/unnamed beacon on startup")
            }
        }
        
        if let poi = destination?.getPOI(), let userLocation = userLocation {
            // Determine if user is within geofence
            isWithinGeofence = isLocationWithinGeofence(origin: poi, location: userLocation)
        }
        
        // Listen for updates to `collectionHeading`
        collectionHeading.onHeadingDidUpdate { [weak self] (_ heading: HeadingValue?) in
            guard let `self` = self else {
                return
            }
            
            // Don't directly access the beacon POI - we don't want to have to retrieve it from
            // the database at frequency we receive heading updates. Instead, just check if there is
            // currently a beacon playing, and then only update the `isBeaconInBounds` flag if there is.
            guard self.beaconPlayerId != nil else {
                return
            }
            
            if let heading = heading?.value {
                self.isBeaconInBounds = self.isBeaconInBounds(with: heading)
            } else {
                self.isBeaconInBounds = false
            }
        }

        NotificationCenter.default.addObserver(self, 
                                       selector: #selector(self.onSpeedChanged(_:)), 
                                       name: Notification.Name.speedDidChange, 
                                       object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onLocationUpdated), name: Notification.Name.locationUpdated, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onEnableGeofence(_:)), name: NSNotification.Name.enableDestinationGeofence, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onDisableGeofence(_:)), name: NSNotification.Name.disableDestinationGeofence, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioEngineStateChanged(_:)), name: NSNotification.Name.audioEngineStateChanged, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppDidInitialize(_:)), name: NSNotification.Name.appDidInitialize, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onCadenceDidChange(_:)), name: Notification.Name.cadenceDidChange, object: nil)
    }
    
    // MARK: Manage Destination Methods
    
    /// Checks whether the current destination is the specified key.
    /// - Parameters:
    ///   - key: the destination's entity key in the `SpatialDataCache`. Same as the referenceID in `setDestination()`.
    /// - Returns: `false` if the destination isn't set or the entity key doesn't match the destination
    func isDestination(key: String) -> Bool {
        guard destinationKey == key || destination?.entityKey == key else {
            // Return false if the destination isn't set or the entityKey doesn't match the destination
            return false
        }
        
        return true
    }
    
    /// Sets the provided ReferenceEntity as the current destination.
    ///
    /// - Parameters:
    ///   - referenceID: ID of the ReferenceEntity to set as the destination
    ///   - enableAudio: Flag indicating if the beacon should be turned on automatically for the destination
    ///   - userLocation: The user's current location
    ///   - logContext: The context of the call that will be passed to the telemetry service
    /// - Throws: If the destination cannot be set
    func setDestination(referenceID: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws {
        guard let entity = SpatialDataCache.referenceEntityByKey(referenceID) else {
            throw DestinationManagerError.referenceEntityDoesNotExist
        }
        
        destinationKey = referenceID
        isGeofenceEnabled = true
        isWithinGeofence = false
        
        if let userLoc = userLocation ?? AppContext.shared.geolocationManager.location {
            startLocation = userLoc
            distanceTraveled = 0.0 // Reset distance traveled
            updateBeaconClosestLocation(for: userLoc)
        }
        
        if let heading = collectionHeading.value {
            isBeaconInBounds = isBeaconInBounds(with: heading)
        } else {
            isBeaconInBounds = false
        }
        
        // If user location is known, is user within geofence?
        if let userLocation = userLocation {
            isWithinGeofence = isLocationWithinGeofence(origin: entity.getPOI(), location: userLocation)
        }

        // Calculate ETA if the user is not within the geofence
        if let userLocation = userLocation, !isWithinGeofence {
            let destinationLocation = CLLocation(latitude: entity.latitude, longitude: entity.longitude)


            let origin = userLocation // <-- use directly
            let destination = destinationLocation

            Task {
                if let eta = await MapsDecoder.fetchWalkingTimeInSeconds(origin: origin, destination: destination) {
                    destinationETA = Double(eta)
                    targetTime = Date(timeIntervalSinceNow: destinationETA!)
                    LogSession.shared.appendLog(entry: "Target time set to: \(targetTime!)")
                    LogSession.shared.appendLog(entry: "🕒 ETA from MapsDecoder: \(eta) seconds")
                } else {
                    LogSession.shared.appendLog(entry: "⚠️ Failed to fetch ETA from MapsDecoder")
                }
            }

            stepTracker = StepTracker()
            stepTracker?.startTracking(interval: 10) // Start tracking with a 10-second interval
            LogSession.shared.appendLog(entry: "[DestinationManager] Step tracking started after setting destination.")

            // let distance: CLLocationDistance = entity.getPOI().distanceToClosestLocation(from: userLocation)
            // let hardcodedSpeed: Double = 1.4 // Speed in meters per second (average walking speed)
            // // speed = distanceso far since destination was set / cadence so far since destination was set * time since destination was set
            
            // if hardcodedSpeed > 0 {
            //     destinationETA = distance / hardcodedSpeed // ETA in seconds
            //     print("Calculated ETA for destination: \(destinationETA!) seconds")
            // } else {
            //     destinationETA = nil
            //     print("Unable to calculate ETA: Speed is zero or invalid")
            // }
            
        } else {
            destinationETA = nil
            print("User is within geofence, ETA not calculated")
        }
        
        // Start audio if enabled and user is not within geofence
        if let location = userLocation, enableAudio, !isWithinGeofence {
            enableDestinationAudio(userLocation: location)
        } else if isAudioEnabled {
            // If not, and the audio is already on, turn it off (e.g. user is within the geofence of the new beacon already)
            disableDestinationAudio()
        }
        
        try entity.updateLastSelectedDate()
        
        notifyDestinationChanged(id: referenceID)
        
        if FirstUseExperience.didComplete(.oobe) {
            updateNowPlayingDisplay(for: userLocation)
            GDATelemetry.helper?.beaconCountSet += 1
        }

        
        // Log the destination change and notify the rest of the app
        GDATelemetry.track("beacon.added", with: (logContext != nil) ? ["context": logContext!] : nil)
    }
    
    /// Creates a temporary reference entity for the location specified and sets it as the current
    /// destination. When this destination is later cleared, the temporary reference entity will be removed.
    ///
    /// - Parameters:
    ///   - location: Generic location to set as a destination
    ///   - address: Estimated address of the generic location
    ///   - enableAudio: Flag indicating if the beacon should be turned on automatically for the destination
    ///   - userLocation: The user's current location
    ///   - logSource: The context of the call that will be passed to the telemetry service
    /// - Returns: The id of the reference entity set as the destination
    /// - Throws: If the temp reference entity cannot be created or if destination cannot be set
    @discardableResult
    func setDestination(location: CLLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String {
        // The generic location cannot already exist if this method is called, so go ahead and create one
        let genericLoc: GenericLocation = GenericLocation(lat: location.coordinate.latitude,
                                                          lon: location.coordinate.longitude,
                                                          name: address == nil ? GDLocalizedString("beacon.audio_beacon") : GDLocalizationUnnecessary(""))
        
        return try setDestination(location: genericLoc, address: address, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
    }
    
    @discardableResult
    func setDestination(location: GenericLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String {
        // If the reference entity already exists, just set the destination to that
        if let ref = SpatialDataCache.referenceEntityByGenericLocation(location) {
            try setDestination(referenceID: ref.id, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
            
            return ref.id
        }
        
        let refID = try ReferenceEntity.add(location: location, estimatedAddress: address, temporary: true)
        
        // Set the newly created generic location as the destination
        try setDestination(referenceID: refID, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
        
        return refID
    }
    
    /// Creates a temporary reference entity for the location specified and sets it as the current
    /// destination. When this destination is later cleared, the temporary reference entity will be removed.
    /// This version of the `setDestination` method is intended for custom behaviors that use audio beacons.
    ///
    /// - Parameters:
    ///   - location: Generic location to set as a destination
    ///   - behavior: Name of the custom behavior this beacon is being created for
    ///   - enableAudio: Flag indicating if the beacon should be turned on automatically for the destination
    ///   - userLocation: The user's current location
    ///   - logSource: The context of the call that will be passed to the telemetry service
    /// - Returns: The id of the reference entity set as the destination
    /// - Throws: If the temp reference entity cannot be created or if destination cannot be set
    @discardableResult
    func setDestination(location: CLLocation, behavior: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String {
        // The generic location cannot already exist if this method is called, so go ahead and create one
        let genericLoc: GenericLocation = GenericLocation(lat: location.coordinate.latitude, lon: location.coordinate.longitude, name: GDLocalizationUnnecessary(""))
        let refID = try ReferenceEntity.add(location: genericLoc, nickname: behavior, estimatedAddress: nil, temporary: true)
        
        // Set the newly created generic location as the destination
        try setDestination(referenceID: refID, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
        
        return refID
    }
    
    /// Creates a temporary reference entity for the underlying POI with the provided entityKey (if one
    /// doesn't already exist, in which case the existing reference entity will be used), and sets it as
    /// the current destination. When this destination is later cleared, the temporary reference entity
    /// will be removed (if a temporary reference entity was created).
    ///
    /// - Parameters:
    ///   - entityKey: Entity key for the POI to set as the destination
    ///   - enableAudio: Flag indicating if the beacon should be turned on automatically for the destination
    ///   - userLocation: The user's current location
    ///   - estimatedAddress: Estimated address of the POI. Ignored if the entityKey corresponds to a marker
    ///   - logContext: The context of the call that will be passed to the telemetry service
    /// - Returns: The id of the reference entity set as the destination
    /// - Throws: If the temp reference entity cannot be created or if destination cannot be set
    @discardableResult
    func setDestination(entityKey: String, enableAudio: Bool, userLocation: CLLocation?, estimatedAddress: String?, logContext: String?) throws -> String {
        // If the reference entity already exists, just set the destination to that
        if let ref = SpatialDataCache.referenceEntityByEntityKey(entityKey) {
            try setDestination(referenceID: ref.id, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
            
            return ref.id
        }
        
        let refID = try ReferenceEntity.add(entityKey: entityKey, nickname: nil, estimatedAddress: estimatedAddress, temporary: true)
        try setDestination(referenceID: refID, enableAudio: enableAudio, userLocation: userLocation, logContext: logContext)
        
        return refID
    }
    
    /// Clears the current destination and removes all temporary reference entities
    /// from the database. If the audio beacon is enabled, it will be turned off.
    /// Finally, this method sends a destination changed notification with a nil ID
    /// after the destination has been cleared.
    ///
    /// - Throws: If temporary reference entities can not be deleted
    func clearDestination(logContext: String?) throws {
        // Remove all temporary reference entities
        try ReferenceEntity.removeAllTemporary()
        
        beaconClosestLocation = nil
        temporaryBeaconClosestLocation = nil
        
        isBeaconInBounds = false

        startLocation = nil
        distanceTraveled = 0.0
        
        // Clear the destination key to clear the destination
        destinationKey = nil

        stepTracker?.stopTracking()
        stepTracker = nil
        LogSession.shared.appendLog(entry: "[DestinationManager] Step tracking stopped after clearing destination.")

        
        // Turn off the audio
        proximityBeaconPlayerId = nil
        _beaconPlayerId = nil
        
        hapticBeacon?.stop()
        hapticBeacon = nil
        
        // Log the destination change and notify the rest of the app
        GDATelemetry.track("beacon.removed", with: (logContext != nil) ? ["context": logContext!] : nil)

        notifyDestinationChanged(id: nil)
        
        updateNowPlayingDisplay()
    }
    
    // MARK: Manage Audio Methods
    
    /// Toggles the audio beacon on or off for the current destination.
    ///
    /// - Returns: True if the audio beacon was toggled, false otherwise (e.g. no destination is set or user's location is unknown).
    @discardableResult
    func toggleDestinationAudio(_ sendNotfication: Bool, automatic: Bool, forceMelody: Bool) -> Bool {
        let isRouteBeacon = AppContext.shared.eventProcessor.activeBehavior is RouteGuidance
        guard destination != nil else {
            // Return if destination does not exist
            return false
        }
        
        if isAudioEnabled {
            if !automatic {
                GDATelemetry.track("beacon.toggled", with: ["enabled": "false", "route": String(isRouteBeacon)])
            }
            
            if forceMelody {
                finishBeaconPlayerOnRemove = true
            }
            
            return disableDestinationAudio(sendNotfication)
        }
        
        guard let userLocation = AppContext.shared.geolocationManager.location else {
            return false
        }
        
        if !automatic {
            GDATelemetry.track("beacon.toggled", with: ["enabled": "true", "route": String(isRouteBeacon)])
        }
        
        return enableDestinationAudio(userLocation: userLocation, isUnmuting: !forceMelody, notify: sendNotfication)
    }
    
    /// Moves the beacon's audio to a new location without changing the underlying beacon.
    /// This is primarily used when editing a marker's location using the custom VO experience.
    ///
    /// - Parameters:
    ///   - newLocation: New location for the beacon audio
    ///   - userLocation: User's current location
    ///
    @discardableResult
    func updateDestinationLocation(_ newLocation: CLLocation, userLocation: CLLocation) -> Bool {
        temporaryBeaconClosestLocation = newLocation
        return enableDestinationAudio(beaconLocation: newLocation, userLocation: userLocation, isUnmuting: false, notify: false)
    }
    
    /// Enables the audio beacon sound for the current destination, if one is set.
    ///
    /// - Parameters:
    ///   - beaconLocation: This value is used to temporarily move the beacon from its original location without setting a new beacon. This is primarily used when editing a marker's location using the custom VO experience
    ///   - userLocation: User's current location
    ///   - isUnmuting: Used to determine whether to play the start melody
    ///   - sendNotfication: Should there be a notification telling the rest of the app that the audio was enabled
    ///
    /// - Returns: True is the audio beacon was turned on, false otherwise (e.g. no destination is set).
    @discardableResult
    private func enableDestinationAudio(beaconLocation: CLLocation? = nil, userLocation: CLLocation, isUnmuting: Bool = false, notify sendNotfication: Bool = false) -> Bool {
        guard let destination = destination else {
            // Return if destination could not be retrieved
            return false
        }
        
        var args = BeaconArgs(loc: beaconLocation ?? destination.closestLocation(from: userLocation),
                              heading: Heading(from: collectionHeading),
                              startMelody: SettingsContext.shared.playBeaconStartAndEndMelodies && !isUnmuting,
                              endMelody: SettingsContext.shared.playBeaconStartAndEndMelodies)
        
        if AppContext.shared.eventProcessor.activeBehavior is RouteGuidance || AppContext.shared.eventProcessor.activeBehavior is GuidedTour {
            guard let hum = BeaconSound(ProximityBeacon.self, at: args.loc, isLocalized: false) else {
                return false
            }
            
            proximityBeaconPlayerId = audioEngine.play(hum)
            
            // Always play the start and end melodies in the route guidance (except for when the beacon is just being unmuted)
            args.startMelody = !isUnmuting
            args.endMelody = true
        }
        
        switch SettingsContext.shared.selectedBeacon {
        case V2Beacon.description: playBeacon(V2Beacon.self, args: args)
        case FlareBeacon.description: playBeacon(FlareBeacon.self, args: args)
        case ShimmerBeacon.description: playBeacon(ShimmerBeacon.self, args: args)
        case TactileBeacon.description: playBeacon(TactileBeacon.self, args: args)
        case PingBeacon.description: playBeacon(PingBeacon.self, args: args)
        case DropBeacon.description: playBeacon(DropBeacon.self, args: args)
        case SignalBeacon.description: playBeacon(SignalBeacon.self, args: args)
        case SignalSlowBeacon.description: playBeacon(SignalSlowBeacon.self, args: args)
        case SignalVerySlowBeacon.description: playBeacon(SignalVerySlowBeacon.self, args: args)
        case MalletBeacon.description: playBeacon(MalletBeacon.self, args: args)
        case MalletSlowBeacon.description: playBeacon(MalletSlowBeacon.self, args: args)
        case MalletVerySlowBeacon.description: playBeacon(MalletVerySlowBeacon.self, args: args)
        case FollowTheMusicBeacon.description: playBeacon(FollowTheMusicBeacon.self, args: args)
        case WalkAMileInMyShoesBeacon.description: playBeacon(WalkAMileInMyShoesBeacon.self, args: args)
        case NoTonesPleaseBeacon.description: playBeacon(NoTonesPleaseBeacon.self, args: args)
        case SilenceIsGolden1Beacon.description: playBeacon(SilenceIsGolden1Beacon.self, args: args)
        case SilenceIsGolden2Beacon.description: playBeacon(SilenceIsGolden2Beacon.self, args: args)
        case TheNewNoiseBeacon.description: playBeacon(TheNewNoiseBeacon.self, args: args)
        case AfricaBeacon.description: playBeacon(AfricaBeacon.self, args: args)
        case NoTonesV2Beacon.description: playBeacon(NoTonesV2Beacon.self, args: args)
        case SoundcloudBeacon.description: playBeacon(SoundcloudBeacon.self, args: args)
        case TheNewerNoiseBeacon.description: playBeacon(TheNewerNoiseBeacon.self, args: args)
        case VolvoBeacon.description: playBeacon(VolvoBeacon.self, args: args)
        case Volvo2Beacon.description: playBeacon(Volvo2Beacon.self, args: args)
        case HapticWandBeacon.description:
            hapticBeacon = HapticWandBeacon(at: args.loc)
            hapticBeacon?.start()
            isCurrentBeaconAsyncFinishable = false
        case HapticPulseBeacon.description:
            hapticBeacon = HapticPulseBeacon(at: args.loc)
            hapticBeacon?.start()
            isCurrentBeaconAsyncFinishable = false
        default:
            // Always default to the V1 beacon
            playBeacon(ClassicBeacon.self, args: args)
        }
        
        guard beaconPlayerId != nil  || hapticBeacon != nil else {
            GDLogAppError("Unable to start beacon audio player")
            return false
        }
        
        if sendNotfication {
            notifyDestinationAudioChanged()
        }
        
        return true
    }
    
    /// Generic helper function for creating a beacon sound and passing it to the audio engine given a DynamicAudioEngineAsset type
    ///
    /// - Parameters:
    ///   - assetType: Asset type to create a beacon sound for
    ///   - args: Beacon settings
    private func playBeacon<T: DynamicAudioEngineAsset>(_ assetType: T.Type, args: BeaconArgs) {
        guard let sound = BeaconSound(assetType, at: args.loc, includeStartMelody: args.startMelody, includeEndMelody: args.endMelody) else {
            GDLogAppError("Beacon sound failed to load!")
            return
        }
        
        isCurrentBeaconAsyncFinishable = sound.outroAsset != nil
        _beaconPlayerId = audioEngine.play(sound, heading: args.heading)
        
        // Attempt to retrieve the layer
        if let layer = audioEngine.getPlayer(for: beaconPlayerId!) {
            // Access the layer and perform any necessary operations
            print("Successfully accessed the layer: \(layer)")
        } else {
            GDLogAppError("Failed to access the layer for the beacon player ID")
        }
    }
    
    /// Disables the audio beacon for the current destination, if one is set.
    ///
    /// - Returns: True if the audio beacon was turned off, false otherwise (e.g. no destination is set).
    @discardableResult
    private func disableDestinationAudio(_ sendNotfication: Bool = false) -> Bool {
        guard destination != nil else {
            // Return if destination does not exist
            return false
        }
        
        // Turn off audio
        proximityBeaconPlayerId = nil
        _beaconPlayerId = nil
        
        hapticBeacon?.stop()
        hapticBeacon = nil
        
        if sendNotfication {
            notifyDestinationAudioChanged()
        }
        
        return true
    }
    
    private func updateBeaconClosestLocation(for location: CLLocation) {
        guard let poi = destination?.getPOI() else {
            return
        }
        
        beaconClosestLocation = poi.closestLocation(from: location)
    }
    
    private func isBeaconInBounds(with userHeading: Double) -> Bool {
        guard let userLocation = AppContext.shared.geolocationManager.location else {
            return false
        }
        
        guard let beaconLocation = temporaryBeaconClosestLocation ?? beaconClosestLocation else {
            return false
        }
        
        let bearingToClosestLocation = userLocation.bearing(to: beaconLocation)
        
        guard let directionRange = DirectionRange(direction: bearingToClosestLocation, windowRange: 45) else {
            return false
        }
        
        return directionRange.contains(userHeading)
    }
    
    // MARK: Manage Arrival Methods
    
    @objc private func onEnableGeofence(_ notification: NSNotification) {
        isGeofenceEnabled = true
    }
    
    @objc private func onDisableGeofence(_ notification: NSNotification) {
        isGeofenceEnabled = false
    }
    
    func isUserWithinGeofence(_ userLocation: CLLocation) -> Bool {
        guard let poi = destination?.getPOI() else {
            return false
        }
        
        return isLocationWithinGeofence(origin: poi, location: userLocation)
    }
    
    private func isLocationWithinGeofence(origin: POI, location: CLLocation) -> Bool {
        guard isGeofenceEnabled else {
            return false
        }
        
        if origin.contains(location: location.coordinate) {
            return true
        }
        
        let distance = origin.distanceToClosestLocation(from: location)
        
        if isWithinGeofence && distance >= SettingsContext.shared.leaveImmediateVicinityDistance {
            // Left immediate vicinity
            return false
        } else if !isWithinGeofence && distance <= SettingsContext.shared.enterImmediateVicinityDistance {
            // Entered immediate vicinity
            return true
        }
        
        // No change
        return isWithinGeofence
    }
    
    private func shouldTriggerGeofence(location: CLLocation) -> Bool {
        guard isGeofenceEnabled else {
            GDLogAppInfo("shouldTriggerGeofence: Geofence disabled!")
            return false
        }
        
        let oldValue = isWithinGeofence
        
        isWithinGeofence = isUserWithinGeofence(location)
        
        if oldValue == isWithinGeofence {
            return false
        }
        
        return true
    }

func setDestinationETA(newETA: Double, window: Double) {
    let currentTime = Date()
    let targetTimeInterval = targetTime?.timeIntervalSince(currentTime) ?? 0

    LogSession.shared.appendLog(entry: "setDestinationETA: Current time: \(currentTime)")
    LogSession.shared.appendLog(entry: "setDestinationETA: Target time interval: \(targetTimeInterval)")
    LogSession.shared.appendLog(entry: "setDestinationETA: New ETA: \(newETA), Window: \(window)")

    if targetTimeInterval < newETA - window {
        // User is behind schedule
        if lastPaceState != .speedingUp {
            LogSession.shared.appendLog(entry: "setDestinationETA: User is behind schedule. Changing pace state to speedingUp.")
            LogSession.shared.appendLog(entry: "setDestinationETA: Previous pace state: \(lastPaceState), New pace state: speedingUp.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .cadenceDidChange, object: nil, userInfo: ["playbackSpeed": Float(15.0)])
            }
            lastPaceState = .speedingUp
        }
        LogSession.shared.appendLog(entry: "setDestinationETA: User is behind schedule but not this (lastPaceState != .speedingUp)")
    } else if targetTimeInterval > newETA + window {
        // User is ahead of schedule
        if lastPaceState != .slowingDown {
            LogSession.shared.appendLog(entry: "setDestinationETA: User is ahead of schedule. Changing pace state to slowingDown.")
            LogSession.shared.appendLog(entry: "setDestinationETA: Previous pace state: \(lastPaceState), New pace state: slowingDown.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .cadenceDidChange, object: nil, userInfo: ["playbackSpeed": Float(-15.0)])
            }
            lastPaceState = .slowingDown
        }
        LogSession.shared.appendLog(entry: "setDestinationETA: User is ahead of schedule but not this (lastPaceState != .slowingDown)")
    } else {
        // User is on pace
        if lastPaceState != .onPace {
            LogSession.shared.appendLog(entry: "setDestinationETA: User is on pace. Changing pace state to onPace.")
            LogSession.shared.appendLog(entry: "setDestinationETA: Previous pace state: \(lastPaceState), New pace state: onPace.")
            lastPaceState = .onPace
        }
        LogSession.shared.appendLog(entry: "setDestinationETA: User is on pace but not this (lastPaceState != .onPace)")
    }



        // // Calculate the percentage difference if the current ETA is not nil
        // if let currentETA = destinationETA {
        //     let difference = (newETA - currentETA)
        //     percentageDifferenceInETA = (difference / currentETA) * 100
        //     LogSession.shared.appendLog(entry: "Current ETA: \(currentETA), New ETA: \(newETA), Difference: \(difference), Percentage Difference: \(percentageDifferenceInETA)%")
        //     let userInfo: [String: Any] = ["playbackSpeed": Float(percentageDifferenceInETA)]
        //     let notification = Notification(name: .cadenceDidChange, object: nil, userInfo: userInfo)
        //     // Call the method directly with the simulated notification
        //     // onCadenceDidChange(notification) 

        //     // if targetTimeInterval < ETA - window → speedUp
        //     // if targetTimeInterval > ETA + window → slowDown
        //     // else → onPace   
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //         NotificationCenter.default.post(name: .cadenceDidChange, object: nil, userInfo: ["playbackSpeed": Float(percentageDifferenceInETA)])
        //     }
        // } else {
        //     // If there is no current ETA, set the percentage difference to 0
        //     percentageDifferenceInETA = 0.0
        // }

        // // Log the percentage difference
        // LogSession.shared.appendLog(entry: "Percentage difference in ETA: \(percentageDifferenceInETA)%")

        // // Set the new ETA value
        // destinationETA = newETA

        // // Log the new ETA value
        // LogSession.shared.appendLog(entry: "New destination ETA set: \(destinationETA!) seconds")
    }
    
    // MARK: Notifications

    @objc private func onSpeedChanged(_ notification: Notification) {
        LogSession.shared.appendLog(entry: "onSpeedChanged: Received speed change notification with speed: \(notification.userInfo?["speed"] ?? "unknown")")

    // Extract the new speed from the notification
    guard let userInfo = notification.userInfo,
          let newSpeed = userInfo["speed"] as? Double else {
        print("onSpeedChanged: Missing or invalid speed in notification")
        return
    }

    // Validate the speed
    guard newSpeed > 0 else {
        LogSession.shared.appendLog(entry:"onSpeedChanged: Invalid speed value (\(newSpeed)). Must be greater than 0.")
        destinationETA = nil
        return
    }


    // Ensure a destination is set
    guard let destination = destination,
          let userLocation = AppContext.shared.geolocationManager.location else {
        print("onSpeedChanged: No destination or user location available, speed is (\(newSpeed))")
        destinationETA = nil
        return
    }

    // Check if the user is within the geofence
    isWithinGeofence = isLocationWithinGeofence(origin: destination.getPOI(), location: userLocation)
    if isWithinGeofence {
        print("onSpeedChanged: User is within geofence, ETA not calculated")
        destinationETA = nil
        return
    }

    // Calculate the ETA
    LogSession.shared.appendLog(entry: "onSpeedChanged: Calculating ETA with new speed: \(newSpeed)")

    // Calculate the distance to the closest location of the destination
    let distance = destination.getPOI().distanceToClosestLocation(from: userLocation)
    LogSession.shared.appendLog(entry: "onSpeedChanged: Distance to destination: \(distance) meters")

    let Δv = 0.1 // Hardcoded value for velocity adjustment
    let k = 1.2 // Hardcoded scaling factor

    let jitterHalf = (distance / (newSpeed * newSpeed)) * Δv
    LogSession.shared.appendLog(entry: "onSpeedChanged: Calculated jitterHalf: \(jitterHalf)")

    let window = k * jitterHalf
    LogSession.shared.appendLog(entry: "onSpeedChanged: Calculated window for cadence adjustment: \(window)")

    // NotificationCenter.default.post(name: .cadenceDidChange, object: nil, userInfo: ["playbackSpeed": Float(15.0)])
    setDestinationETA(newETA: distance / newSpeed, window: window ) // ETA in seconds
}

    @objc private func onCadenceDidChange(_ notification: Notification) {
    LogSession.shared.appendLog(entry:" onCadenceDidChange ")
    // Validate that `_beaconPlayerId` exists
    guard let beaconPlayerId = _beaconPlayerId else {
        GDLogAppError("Failed to update playback speed: No active beacon player.")
        return
    }
    
    // Retrieve the playback speed percentage from the notification
    GDLogAppInfo("Received cadenceDidChange notification.")
    
    // Validate and extract userInfo
    guard let userInfo = notification.userInfo else {
        GDLogAppError("cadenceDidChange notification missing userInfo.")
        return
    }
    GDLogAppInfo("cadenceDidChange userInfo: \(userInfo)")
    
    // Extract playback speed
    guard let playbackSpeed = userInfo["playbackSpeed"] as? Float else {
        GDLogAppError("cadenceDidChange notification missing playbackSpeed or invalid type.")
        return
    }
    GDLogAppInfo("Extracted playbackSpeed: \(playbackSpeed)")
    
    // Validate playback speed
    guard playbackSpeed != 0 else {
        GDLogAppError("Invalid playbackSpeed value: \(playbackSpeed). Must not be zero.")
        return
    }
    GDLogAppInfo("Validated playbackSpeed: \(playbackSpeed)")
    
    // Retrieve the player from the audio engine
        guard let player = audioEngine.getPlayer(for: beaconPlayerId) as? AudioPlayer else {
        GDLogAppError("Failed to retrieve player for beaconPlayerId: \(beaconPlayerId.uuidString)")
        return
    }
    
    // Update the playback speed
    player.setPlaybackSpeed(byPercentage: playbackSpeed)
    
    // Optionally log or notify about the successful update
    GDLogAppInfo("Playback speed updated to \(playbackSpeed) for player \(beaconPlayerId.uuidString).")
    LogSession.shared.appendLog(entry: "Playback speed updated to \(playbackSpeed) for player \(beaconPlayerId.uuidString).")

}
    
    @objc private func onLocationUpdated(_ notification: Notification) {
        // TODO: All of this logic (callout and view update logic) should moved into
        //       the BeaconCalloutGenerator

        guard let userInfo = notification.userInfo,
            let location = userInfo[SpatialDataContext.Keys.location] as? CLLocation else {
            GDLogSpatialDataError("Error: LocationUpdated notification is missing location")
            return
        }

        // Calculate the distance traveled
        if let startLocationInUpdatedMethod = startLocation {
            let distance = haversineDistance(from: startLocationInUpdatedMethod, to: location)
            distanceTraveled = distance // for now, distance traveled is the distance between the start location and the current location
            LogSession.shared.appendLog(entry: "distanceTraveled: \(distanceTraveled)")

            // Notify subscribers if the distance exceeds the threshold
            if distance >= distanceThreshold {
                // LogSession.shared.appendLog(entry: "distanceTraveled threshold: \(distanceTraveled)")
                NotificationCenter.default.post(name: Notification.Name("DistanceTraveledUpdated"),
                                                object: self,
                                                userInfo: ["distanceTraveled": distanceTraveled])
            }   
        } else {
            LogSession.shared.appendLog(entry: "start location is nil \( startLocation))")
            startLocation = location // in what condtion will this happen? give me an example walkthrough
        }
        
        guard !AppContext.shared.eventProcessor.activeBehavior.blockedAutoGenerators.contains(where: { $0 == BeaconCalloutGenerator.self }) else {
            GDLogAutoCalloutInfo("Skipping beacon geofence update. Beacon callouts are managed by the active behavior.")
            return
        }
        
        guard let userInfo = notification.userInfo else {
            GDLogSpatialDataError("Error: No userInfo with location update")
            return
        }
        
        guard let key = destinationKey else {
            return
        }
        
        guard let location = userInfo[SpatialDataContext.Keys.location] as? CLLocation else {
            GDLogSpatialDataError("Error: LocationUpdated notification is missing location")
            return
        }
        
        updateBeaconClosestLocation(for: location)
        
        updateNowPlayingDisplay(for: location)
        
        guard shouldTriggerGeofence(location: location) else {
            return
        }
        
        let wasAudioEnabled = isAudioEnabled
        
        // Disable audio when entering the geofence, but require the user to manually turn audio
        // back on if they leave the geofence
        if isWithinGeofence {
            GDATelemetry.track("beacon.arrived")
            GDATelemetry.helper?.beaconCountArrived += 1
            
            disableDestinationAudio()
        }
        
        GDLogAppInfo("Geofence Triggered: \(isWithinGeofence ? "Entered" : "Exited")")
        
        AppContext.process(BeaconGeofenceTriggeredEvent(beaconId: key,
                                                        didEnter: isWithinGeofence,
                                                        beaconIsEnabled: isAudioEnabled,
                                                        beaconWasEnabled: wasAudioEnabled,
                                                        location: location))
        
        NotificationCenter.default.post(name: Notification.Name.destinationGeofenceDidTrigger,
                                        object: self,
                                        userInfo: [DestinationManager.Keys.destinationKey: key,
                                                   DestinationManager.Keys.geofenceDidEnter: isWithinGeofence,
                                                   DestinationManager.Keys.isAudioEnabled: isAudioEnabled,
                                                   DestinationManager.Keys.wasAudioEnabled: wasAudioEnabled,
                                                   SpatialDataContext.Keys.location: location])
    }
    
    private func updateNowPlayingDisplay(for location: CLLocation? = nil) {
        if appDidInitialize {
            guard !(AppContext.shared.eventProcessor.activeBehavior is RouteGuidance) else {
                // `RouteGuidance` will set the "Now Playing" text
                return
            }
        }
        
        guard let location = location, let destination = destination else {
            AudioSessionManager.removeNowPlayingInfo()
            return
        }
        
        let name = GDLocalizedString("beacon.beacon_on", destination.name)
        let distance = destination.distanceToClosestLocation(from: location)
        let formattedDistance = LanguageFormatter.formattedDistance(from: distance)
        
        AudioSessionManager.setNowPlayingInfo(title: name, subtitle: formattedDistance)
    }
    
    @objc private func onAudioEngineStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let stateValue = userInfo[AudioEngine.Keys.audioEngineStateKey] as? Int,
              let state = AudioEngine.State(rawValue: stateValue) else {
                return
        }
        
        if state == .stopped && isAudioEnabled {
            toggleDestinationAudio()
            didInterruptBeacon = true
        } else if state == .started && didInterruptBeacon {
            toggleDestinationAudio()
            didInterruptBeacon = false
        }
    }
    
    @objc private func onAppDidInitialize(_ notification: Notification) {
        appDidInitialize = true
    }

    private func haversineDistance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        let radius: Double = 6_371_000 // meters
        let lat1 = from.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180

        let dlat = lat2 - lat1
        let dlon = lon2 - lon1

        let a = sin(dlat / 2) * sin(dlat / 2) +
                cos(lat1) * cos(lat2) *
                sin(dlon / 2) * sin(dlon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        let distance = radius * c
        LogSession.shared.appendLog(entry: "Haversine distance calculated: \(distance) meters")
        return distance
    }

    
    private func notifyDestinationChanged(id: String?) {
        var userInfo: [String: Any]?
        
        if let id = id {
            userInfo = [DestinationManager.Keys.destinationKey: id,
                        DestinationManager.Keys.isAudioEnabled: isAudioEnabled]
        }
        
        DispatchQueue.main.async {
            AppContext.process(BeaconChangedEvent(id: id, audioEnabled: self.isAudioEnabled))
            
            NotificationCenter.default.post(name: Notification.Name.destinationChanged, object: self, userInfo: userInfo)
        }
    }
    
    private func notifyDestinationAudioChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.destinationAudioChanged, object: self, userInfo: [DestinationManager.Keys.isAudioEnabled: self.isAudioEnabled])
        }
    }
    
}
