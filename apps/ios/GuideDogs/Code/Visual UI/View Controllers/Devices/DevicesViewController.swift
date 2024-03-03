//
//  DevicesViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit
import SceneKit
import SceneKit.ModelIO
import AVFoundation
import Combine
import CoreBluetooth

class DevicesViewController: UIViewController {

    // MARK: - Types
    
    private struct Segue {
        static let unwind = "UnwindToHomeSegue"
    }
    
    private enum ButtonState {
        case light
        case dark
    }
    
    private enum SceneState {
        case hidden
        case `static`
        case animating
        case active
    }
    
    private enum State {
        case unknown
        case disconnected
        case pairingAudio
        case firstConnection
        case calibrating
        case completedPairing
        case testHeadset
        case paired
        case connected
        case testBLEConfig
        
        var title: String {
            switch self {
            case .pairingAudio: return GDLocalizedString("devices.title.pair_audio")
            case .firstConnection: return GDLocalizedString("devices.title.first_connection")
            case .calibrating: return GDLocalizedString("devices.title.calibrate")
            case .completedPairing: return GDLocalizedString("devices.title.completed_connection")
            case .testHeadset: return GDLocalizedString("devices.test_headset.title")
            case .testBLEConfig: return "Send test config"
            default: return GDLocalizedString("menu.devices")
            }
        }
        
        var backgroundImage: UIImage? {
            switch self {
            case .unknown, .disconnected: return UIImage(named: "NoDevice")
            case .pairingAudio: return UIImage(named: "PairAudio")
            case .calibrating: return UIImage(named: "Calibrating")
            case .paired: return UIImage(named: "PairedAndNotConnected")
            case .firstConnection, .connected, .completedPairing, .testHeadset, .testBLEConfig: return UIImage(named: "PairedAndConnected")
            }
        }
        
        func sceneState(for device: Device?) -> SceneState {
            switch self {
            case .unknown, .disconnected: return .hidden
            case .firstConnection, .pairingAudio, .paired: return .static
            case .calibrating: return .static
            case .connected, .completedPairing, .testHeadset, .testBLEConfig: return .static
            }
        }
        
        func text(for device: Device?) -> String? {
            switch self {
            case .unknown: return GDLocalizationUnnecessary("")
                
            case .disconnected: return GDLocalizedString("devices.explain_ar.disconnected")
                
            case .pairingAudio: return GDLocalizedString("devices.connect_headset.audio")
                
            case .firstConnection: return GDLocalizedString("devices.connect_headset.calibrate.explanation")
                
            case .calibrating:
                switch device {
                case is HeadphoneMotionManagerWrapper:
                    // Calibration is not necessary
                    return nil
                default:
                    return nil
                }
                
            case .completedPairing:
                switch device {
                case is HeadphoneMotionManagerWrapper:
                    return GDLocalizedString("devices.connect_headset.completed.airpods", device?.model ?? "'unknown type'")
                
                default:
                    return nil
                }
                
            case .testHeadset: return GDLocalizedString("devices.test_headset.explanation")
                
            case .paired:
                switch device {
                case let device as HeadphoneMotionManagerWrapper:
                    GDLogHeadphoneMotionInfo("EARS: UIController.state: \(device.status.value)")
                    if device.status.value == .connected {
                        return GDLocalizedString("devices.explain_ar.connecting", device.name)
                    } else {
                        return GDLocalizedString("devices.explain_ar.paired", device.name)
                    }
                
                default:
                    return nil
                }
                
            case .connected:
                switch device {
                case is HeadphoneMotionManagerWrapper:
                    return GDLocalizedString("devices.explain_ar.connected.airpods", device?.name ?? "'unknown'")
                
                default:
                    return nil
                }
            case .testBLEConfig:
                return "Test sending config data to headset to see if the heading service starts delivering data..."
            }
        }

        // MARK: Visa button text
        func primaryBtnText(for device: Device?) -> String? {
            switch self {
            case .unknown: return GDLocalizationUnnecessary("")
            case .disconnected: return GDLocalizedString("devices.connect_headset")
            case .pairingAudio: return GDLocalizedString("ui.continue")
            case .firstConnection: return GDLocalizedString("devices.connect_headset.calibrate.button")
            case .calibrating: return GDLocalizedString("general.alert.dismiss")
            case .completedPairing, .testHeadset: return GDLocalizedString("devices.test_headset.continue")
            case .paired, .connected:
                if let device = device as? HeadphoneMotionManagerWrapper, device.status.value == .connected {
                    return GDLocalizedString("general.alert.cancel")
                } else {
                    return GDLocalizedString("settings.bluetooth.forget")
                }
            case .testBLEConfig:
                if(device?.type == .bose) {
                    return "Starta headtracking"
                }
                return "Tryck för att skicka nåt.."
            }
        }
        
        var primaryBtnState: ButtonState {
            switch self {
            case .unknown, .disconnected, .pairingAudio, .firstConnection: return .light
            case .calibrating, .paired, .completedPairing, .connected, .testHeadset, .testBLEConfig: return .dark
            }
        }
        
        var secondaryBtnIsHidden: Bool {
            switch self {
            case .completedPairing, .connected: return false
            default: return true
            }
        }
        
        var secondaryBtnText: String? {
            switch self {
            case .completedPairing, .connected: return GDLocalizedString("devices.connect_headset.completed.test")
            default: return nil
            }
        }
        
        func secondaryBtnHint(for device: Device?) -> String? {
            guard let device = device else {
                return nil
            }
            
            return GDLocalizedString("devices.connect_headset.completed.test.hint", device.model)
        }
    }
    
    // MARK: - Properties
    
    let queue = DispatchQueue(label: "services.soundscape.devicesui")
    
    /// Flag set to true if the DevicesViewController was launched automatically (e.g. because the currently
    /// connected headset needs to be recalibrated) or false if it was launched because the user navigated to it
    /// from the main menu.
    var launchedAutomatically = false
    
    /// If the DeviceViewController is used to connect to a new device, this property will be used to hold a
    /// reference to it.
    private var connectedDevice: Device? {
        didSet {
            guard oldValue?.id != connectedDevice?.id else {
                return
            }
            
            if let device = connectedDevice as? HeadphoneMotionManagerWrapper {
                // Start listening for updates
                headphoneMotionStatusSubscriber = device.status
                    .receive(on: RunLoop.main)
                    .sink(receiveValue: { [weak self] (newValue) in
                        guard let `self` = self else {
                            return
                        }
                        
                        guard let device = self.connectedDevice as? HeadphoneMotionManagerWrapper else {
                            return
                        }
                        
                        let oldValue = self.state
                        
                        switch newValue {
                        case .unavailable, .inactive: return // no-op
                        case .disconnected, .connected: self.state = .paired
                        case .calibrated: self.state = device.isFirstConnection ? .completedPairing : .connected
                        }
                        
                        if oldValue == self.state {
                            // If `renderView` is not automatically called because
                            // of a new value for `state`, call it manually
                            DispatchQueue.main.async { [weak self] in
                                self?.renderView()
                            }
                        }
                    })
            } else {
                // Stop listening for updates
                headphoneMotionStatusSubscriber?.cancel()
            }
        }
    }
   
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var text: UILabel!
    @IBOutlet weak var primaryBtn: RoundedSolidButton!
    @IBOutlet weak var primaryBtnLabel: UILabel!
    @IBOutlet weak var secondaryBtn: RoundedSolidButton!
    @IBOutlet weak var secondaryBtnLabel: UILabel!
    @IBOutlet weak var headsetViewContainer: RoundedView!
    @IBOutlet weak var headsetView: SCNView!
    @IBOutlet weak var deviceImageView: UIImageView!
    
    @IBOutlet var primaryBtnConstraints: [NSLayoutConstraint]!
    @IBOutlet var secondaryBtnConstraints: [NSLayoutConstraint]!
    
    private var headphoneMotionStatusSubscriber: AnyCancellable?
    
    private var calibrationObserver: NSObjectProtocol?
    private var calibrationUpdateObserver: NSObjectProtocol?
    private var deviceHeading: Heading?
    
    /// Central heading for displaying the 3D headset view (in radians)
    private var centerHeading: Double?
    
    private var selectedDeviceManagerType: Device.Type?
    private var selectedDeviceName: String?
    private var selectedDeviceModel: String?
    private var selectedDeviceType: DeviceType?
    
    private var state = State.unknown {
        didSet {
            // Only update on state changes
            guard oldValue != state else {
                return
            }
            
            if state == .calibrating && !launchedAutomatically {
                calibrationUpdateObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationUpdated, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                    // Calibration state has updated so rerender the UI as it may have changed
                    DispatchQueue.main.async { [weak self] in
                        self?.renderView()
                    }
                }
                
                calibrationObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                    self?.state = .completedPairing
                    
                    if let updateObserver = self?.calibrationUpdateObserver {
                        NotificationCenter.default.removeObserver(updateObserver)
                        self?.calibrationUpdateObserver = nil
                    }
                    
                    if let observer = self?.calibrationObserver {
                        NotificationCenter.default.removeObserver(observer)
                        self?.calibrationObserver = nil
                    }
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.renderView()
            }
        }
    }
    
    /// Helper for quickly accessing the headset model node from the 3D scene
    private var headsetNode: SCNNode? {
        return headsetView.scene?.rootNode.childNodes.first
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if launchedAutomatically {
            state = .calibrating
        }
        
        if state != .calibrating {
            if let first = AppContext.shared.deviceManager.devices.first {
                if let first = first as? HeadphoneMotionManagerWrapper {
                    if first.status.value == .calibrated {
                        self.state = .connected
                    } else {
                        self.state = .paired
                    }
                } else if first.isConnected {
                    state = .connected
                } else {
                    state = .paired
                }
            } else {
                state = .disconnected
            }
        }
        
        // Remove nav bar shadow for this screen
        navigationController?.navigationBar.configureAppearance(for: .transparentLightTitle)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        GDATelemetry.trackScreenView("devices")
        
        AppContext.shared.deviceManager.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Always start by focusing VO on the header
        if launchedAutomatically {
            UIAccessibility.post(notification: .screenChanged, argument: primaryBtn)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Reset the nav bar images
        navigationController?.navigationBar.configureAppearance(for: .default)
        
        AppContext.shared.deviceManager.delegate = nil
        
        deviceHeading = nil
        
        if let updateObserver = calibrationUpdateObserver {
            NotificationCenter.default.removeObserver(updateObserver)
        }
        
        if let observer = calibrationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Class Methods
    
    /// Renders the view for the current state of the view controller. This method should only be called when
    /// state changes.
    ///
    /// - Parameter withAnimations: Animates the changes to the image view and text label if True
    private func renderView(withAnimations: Bool = true) {
        if withAnimations {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setCompletionBlock { [weak self] in
                UIAccessibility.post(notification: .screenChanged, argument: self?.navigationItem.titleView)
            }
            
            let transition = CATransition()
            transition.type = CATransitionType.fade
            
            imageView.layer.add(transition, forKey: kCATransition)
            text.layer.add(transition, forKey: kCATransition)
        }
        
        let currentDevice = connectedDevice ?? AppContext.shared.deviceManager.devices.first
        
        imageView.image = state.backgroundImage
        text.text = state.text(for: currentDevice)
        
        if withAnimations {
            CATransaction.commit()
        }
        
        navigationItem.rightBarButtonItem = nil
        
        secondaryBtn.isHidden = state.secondaryBtnIsHidden
        secondaryBtn.accessibilityLabel = state.secondaryBtnText
        secondaryBtn.accessibilityHint = state.secondaryBtnHint(for: AppContext.shared.deviceManager.devices.first)
        secondaryBtnLabel.isHidden = state.secondaryBtnIsHidden
        secondaryBtnLabel.text = state.secondaryBtnText
        secondaryBtnLabel.textColor = Colors.Background.secondary
        
        if state.secondaryBtnIsHidden {
            NSLayoutConstraint.deactivate(secondaryBtnConstraints)
            NSLayoutConstraint.activate(primaryBtnConstraints)
        } else {
            NSLayoutConstraint.deactivate(primaryBtnConstraints)
            NSLayoutConstraint.activate(secondaryBtnConstraints)
        }
        
        primaryBtnLabel.text = state.primaryBtnText(for: currentDevice)
        primaryBtnLabel.textColor = state.primaryBtnState == .light ? Colors.Background.secondary : Colors.Foreground.primary
        primaryBtn.backgroundColor = state.primaryBtnState == .light ? Colors.Foreground.primary : Colors.Background.tertiary
        primaryBtn.accessibilityLabel = primaryBtnLabel.text
        
        title = state.title
        
        navigationItem.hidesBackButton = state != .paired && state != .connected && state != .disconnected
        
        if state == .pairingAudio {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: GDLocalizedString("general.alert.cancel"), style: .done, target: self, action: #selector(cancelConnection))
        } else {
            navigationItem.leftBarButtonItem = nil
        }
        
        headsetNode?.removeAllAnimations()
        deviceHeading = nil
        
        switch state.sceneState(for: currentDevice) {
        case .hidden:
            deviceImageView.isHidden = true
            headsetViewContainer.isHidden = true
            
        case .static:
            deviceImageView.image = UIImage(named: "GenericHeadset")
            deviceImageView.isHidden = false
            headsetView.isHidden = true
            
            headsetViewContainer.isHidden = false
            
        case .animating:
            deviceImageView.isHidden = true
            headsetView.isHidden = false
            headsetNode?.eulerAngles = SCNVector3(0.2, 0.0, 0.0)
            setupCalibrationAnimation()
            headsetViewContainer.isHidden = false
            
        case .active:
            deviceImageView.isHidden = true
            headsetView.isHidden = false
            setupActiveAnimation()
            
            headsetViewContainer.isHidden = false
        }
        
        if !withAnimations {
            UIAccessibility.post(notification: .screenChanged, argument: navigationItem.titleView)
        }
    }
    
    private func setupCalibrationAnimation() {
        let angles = CAKeyframeAnimation(keyPath: "eulerAngles")
        angles.values = [
            SCNVector3(0.0, 0.0, 0.0),
            SCNVector3(-0.2, 0.785, 0.0),
            SCNVector3(0.2, 0.785, 0.0),
            SCNVector3(0.0, 0.0, 0.0),
            SCNVector3(-0.2, -0.785, 0.0),
            SCNVector3(0.2, -0.785, 0.0),
            SCNVector3(0.0, 0.0, 0.0)
        ]
        angles.keyTimes = [0, 1, 3, 4, 5, 7, 8]
        angles.duration = 2
        angles.repeatCount = -1
        
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = [
            SCNVector3(0.0, 0.0, 0.0),
            SCNVector3(0.08, 0.0, 0.0),
            SCNVector3(0.0, 0.0, 0.0),
            SCNVector3(-0.08, 0.0, 0.0),
            SCNVector3(0.0, 0.0, 0.0)
        ]
        position.keyTimes = [0, 2, 4, 6, 8]
        position.duration = 2
        position.repeatCount = -1
        
        headsetNode?.addAnimation(angles, forKey: nil)
        headsetNode?.addAnimation(position, forKey: nil)
    }
    
    private func setupActiveAnimation() {
        SCNTransaction.animationDuration = 0.5
        if state == .connected {
            headsetNode?.eulerAngles = SCNVector3(0.2, 0.0, 0.0)
        } else {
            headsetNode?.eulerAngles = SCNVector3(0.350, 0.785, 0.0)
        }
        
        centerHeading = nil
        deviceHeading = AppContext.shared.geolocationManager.heading(orderedBy: [.user])
        deviceHeading?.onHeadingDidUpdate { [weak self] (heading) in
            guard let heading = heading?.value else {
                return
            }
            
            DispatchQueue.main.async {
                self?.renderActiveScene(heading: heading)
            }
        }
    }
    
    /// Renders the active scene by rotating the 3D model of the headset. When the scene is first shown, the model
    /// is oriented straight forward (out of the screen). As the user rotates their head left and right, the 3D model
    /// will mirror their movement. If the user rotates their head further than 22.5° to either side, the 3D model
    /// not rotate beyond that, but will update the center heading used for calculating the rotation of the 3D model.
    /// This ensures that as soon as the user starts to rotate back in the other direction, the 3D model will rotate
    /// with them.
    ///
    /// - Parameter heading: The current heading provided by the headset
    private func renderActiveScene(heading: Double) {
        // Convert the current heading to radians
        let headingRadians = Measurement(value: heading, unit: UnitAngle.degrees).converted(to: .radians).value
        
        // If centerHeading is nil, the scene is just being initialized, so store the current heading as the center
        if centerHeading == nil {
            centerHeading = headingRadians
        }
        
        guard let center = centerHeading else {
            return
        }
        
        // Calculate the offset between the center heading and the current heading and then normalize to the range [-π, π]
        var diff = headingRadians - center
        
        if diff > Double.pi {
            diff -= (Double.pi * 2)
        } else if diff < -Double.pi {
            diff += Double.pi * 2
        }
        
        // If the offset is greater than π/4, then adjust the center heading to only be -π/4 from the current heading
        guard diff < Double.pi / 4 else {
            centerHeading = fmod(headingRadians - Double.pi / 4, 2 * Double.pi)
            return
        }

        // If the offset is less than -π/4, then adjust the center heading to only be π/4 from the current heading
        guard diff > -Double.pi / 4 else {
            centerHeading = fmod(headingRadians + Double.pi / 4, 2 * Double.pi)
            return
        }
        
        // The offset is within [-π/4, π/4] so update the orientation of the 3D scene
        SCNTransaction.animationDuration = 0.05
        headsetNode?.eulerAngles = SCNVector3(0.2, diff, 0.0)
    }
    
    @objc func cancelConnection() {
        state = .disconnected
        selectedDeviceManagerType = nil
        
        if let device = connectedDevice as? HeadphoneMotionManagerWrapper {
            device.disconnect()
        }
    }
    
    @IBAction func onPrimaryBtnTouchUpInside() {
        AppContext.shared.bleManager.authorizationStatus { authorized in
            guard authorized else {
                let alert = ErrorAlerts.buildBLEAlert()
                self.present(alert, animated: true)
                return
            }
            
            self.performPrimaryButtonAction()
        }
    }
    // MARK: performButtonAction
    private func performPrimaryButtonAction() {
        switch state {
        case .disconnected:
            let alert = UIAlertController(title: GDLocalizedString("devices.connect_headset"),
                                          message: GDLocalizedString("devices.connect_headset.explanation"),
                                          preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("devices.airpods.supported_versions"), style: .default, handler: { [weak self] (_) in
                self?.selectedDeviceManagerType = HeadphoneMotionManagerWrapper.self
                self?.selectedDeviceModel = "Apple AirPods"
                self?.selectedDeviceName = "My AirPods"
                self?.selectedDeviceType = .apple
                self?.state = .pairingAudio
            }))
/*
            alert.addAction(UIAlertAction(title: "Sony Linkbuds", style: .default, handler: { [weak self] (_) in
                self?.selectedDeviceManagerType = HeadphoneMotionManagerWrapper.self
                self?.selectedDeviceModel = "Sony Linkbuds"
                self?.selectedDeviceName = "My Linkbuds"
                self?.selectedDeviceType = .sony
                self?.state = .pairingAudio
            }))
*/
            alert.addAction(UIAlertAction(title: "Bose Frames", style: .default, handler: { [weak self] (_) in
                self?.selectedDeviceManagerType = HeadphoneMotionManagerWrapper.self
                self?.selectedDeviceModel = "Bose Frames"
                self?.selectedDeviceName = "Frames"
                self?.selectedDeviceType = .bose
                self?.state = .pairingAudio
            }))
            
            alert.addAction(UIAlertAction(title: "Testing BLE device (Linkbuds)", style: .default, handler: { [weak self] (_) in
                self?.selectedDeviceManagerType = HeadphoneMotionManagerWrapper.self
                self?.selectedDeviceModel = "Generic device"
                self?.selectedDeviceName = "unknown"
                self?.selectedDeviceType = .generic
                self?.state = .pairingAudio
            }))
            
            present(alert, animated: true, completion: nil)
            
        case .pairingAudio:
            guard 
                    let managerType = selectedDeviceManagerType,
                    let deviceType = selectedDeviceType,
                    let modelName = selectedDeviceModel,
                    let deviceName = selectedDeviceName else {
                return
            }
                     
            selectedDeviceManagerType = nil
            connectDevice(of: managerType, name: deviceName, modelName: modelName, deviceType: deviceType)
            
        case .firstConnection:
            if(self.selectedDeviceType == .bose) {
                self.state = .testBLEConfig
                return
            }
            
            if(self.selectedDeviceType == .generic) {
                // Disconnect to trigger debug output
                self.sonyBLEDevice!.printDiscoveredServices()
                self.state = .testBLEConfig
                return
            }
                
            if let device = connectedDevice {
                // Now that we have given the user instructions for calibrating, add the device (which should start the calibration)
                AppContext.shared.deviceManager.add(device: device)
            }
            
            self.state = .calibrating
            
        case .calibrating:
            // Override the calibration procedure
            AppContext.process(CalibrationOverrideEvent())
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationCancelled, object: self)
            
            if let currentDevice = (connectedDevice ?? AppContext.shared.deviceManager.devices.first) as? CalibratableDevice {
                currentDevice.calibrationOverriden = true
            }
            
            if launchedAutomatically {
                dismiss(animated: true, completion: nil)
            } else {
                state = .completedPairing
            }
            
        case .completedPairing:
            // Return to the home screen
            performSegue(withIdentifier: Segue.unwind, sender: self)
            
        case .paired, .connected:
            let alert = UIAlertController(title: GDLocalizedString("devices.forget_headset.prompt.forget"),
                                          message: GDLocalizedString("devices.forget_headset.prompt.explanation"),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.forget"), style: .destructive, handler: { [weak self] (_) in
                if let device = AppContext.shared.deviceManager.devices.first {
                    AppContext.shared.deviceManager.remove(device: device)
                    self?.state = .disconnected
                    self?.connectedDevice = nil
                }
            }))
            
            DispatchQueue.main.async { [weak self] in
                self?.present(alert, animated: true, completion: nil)
            }
           
        case .testHeadset:
            // Stop the test
            AppContext.process(HeadsetTestEvent(.end))
            
            // Return to the home screen
            performSegue(withIdentifier: Segue.unwind, sender: self)
        
        case .testBLEConfig:
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationCancelled, object: self)
            if(self.selectedDeviceType == .bose) {

                guard let _boseBLEDevice = self.boseBLEDevice
                else {
                    GDLogBLEInfo("EARS: WHOOPSIE! BoseDevice is null!")
                    return
                }

                if _boseBLEDevice.currentConnectionState() != .connected {
                    GDLogBLEInfo("EARS: WHOOPSIE! Bose are not connected, trying again....")

                    _boseBLEDevice.connectToBose()
                } else {
                    
                    DispatchQueue.main.async {
                        GDLogBLEInfo("isHeadtrackingStarted: \(_boseBLEDevice.isHeadTrackingStarted())")
                        self.primaryBtnLabel.text = _boseBLEDevice.isHeadTrackingStarted() ? "Stoppa headtracking" : "Starta headtracking"
                    }
//                    UIAccessibility.post(notification: .screenChanged, argument: navigationItem.titleView)
                    if(_boseBLEDevice.isHeadTrackingStarted()) {
                        GDLogBLEInfo("EARS: STOPPING headtracking")
                        _boseBLEDevice.stopHeadTracking()
                        
                    } else {
                        GDLogBLEInfo("EARS: STARTING headtracking")
                        _boseBLEDevice.startHeadTracking()
//                        _boseBLEDevice.testVariousStartCodes()
                    }
/*                    GDLogBLEInfo("EARS: TODO send something to some config characteristic...")
                   let buffer: [UInt32] = [a, b, c]
                    var myData = buffer.withUnsafeBufferPointer {Data(buffer: $0)}
                    boseBLEDevice?.writeValueToConfig(value: myData)
 */
/*
                    //a=a/2
                    //b=b/2
                    c = 256 + testcounter
                    testcounter *= 2
                    for i in 0...10000 {
                        let j = UInt32(i)
                        let buffer: [UInt32] = [a, b, j]
                    
                        var myData = buffer.withUnsafeBufferPointer {Data(buffer: $0)}
                        boseBLEDevice?.writeValueToConfig(value: myData)
                    }
  */

                }
            }
            
        default:
            return
        }
    }
    
    var a: UInt32 = 16777216
    var b: UInt32 = 131072
    var c: UInt32 = 848//1//768
    var testcounter: UInt32 = 1
    @IBAction func onSecondaryBtnTouchUpInside() {
        state = .testHeadset
        AppContext.process(HeadsetTestEvent(.start))
    }
    
    var sonyBLEDevice: SonyBLEDevice?
    var boseBLEDevice: BoseBLEDevice?
    
    private func connectDevice(of managerType: Device.Type, name: String, modelName: String, deviceType: DeviceType) {
        var deviceId = UUID()

        if(deviceType == .bose) {
            if self.boseBLEDevice == nil {
                self.boseBLEDevice = BoseBLEDevice()
            }
            self.boseBLEDevice!.connectToBose()
            
            self.state = .firstConnection
            
            self.selectedDeviceType = .bose
            return
        }
        
        
        if(deviceType == .generic) {
            // TODO: Hitta ett sätt att scanna efter peripherals. Kan man filtrera på service "Headtracking", lyssna på updateringar, och koppla in sig på HeadPhoneManager och skjuta events? Förmodlingen skriva en ny Wrapper? Nix, en implementation av UserHeadingProvider som GeoLocationManager kan anropa för att få uppdateringar. shared.deviceManager.add lägger till Device (som impl UserHeadingProvider) som lägger till den i GeoLocationManager
            /* targetDevice = BaseBLEDevice(peripheral: CBPeripheral, type: .headset) {
             
             }
             AppContext.shared.bleManager.startScan(for: BLEDevice.Type, delegate: T##BLEManagerScanDelegate)
             */
            //AppContext.shared.bleManager.EARS_retrieveDevicesWithServices()
            if self.sonyBLEDevice == nil {
                self.sonyBLEDevice = SonyBLEDevice()
            }
            self.sonyBLEDevice!.scanBLEDevices()
        
            self.state = .firstConnection
            
            self.selectedDeviceType = .generic
            return
        }
        
        managerType.setupDevice(id: deviceId, name: name, modelName: modelName, deviceType: deviceType) { [weak self] (result) in
            guard let `self` = self else {
                return
            }
            
            switch result {
            case .success(let device):
                GDLogHeadphoneMotionInfo("EARS: DeviceViewController.connectDevice: Success connecting device")
                if let device = device as? HeadphoneMotionManagerWrapper {
                    self.connectedDevice = device
                    
                    if device.status.value == .calibrated {
                        self.state = .completedPairing
                    } else {
                        // Device is enabled but not connected
                        AppContext.shared.deviceManager.add(device: device)
                        
                        self.state = .paired
                    }
                } else {
                    // Note that we store the new device rather than adding it to the device manager immediately
                    // so that we can display the firstConnection screen before starting calibration. See `onPrimaryBtnTouchUpInside()`
                    self.connectedDevice = device
                    self.state = .firstConnection
                }
                
            case .failure(let error):
                GDLogHeadphoneMotionInfo("EARS: DeviceViewController.connectDevice: FAIL connecting device")
                let handler: (UIAlertAction) -> Void = { [weak self] (_) in
                    self?.selectedDeviceManagerType = nil
                    self?.state = .disconnected
                    self?.connectedDevice = nil
                }
                
                switch error {
                case DeviceError.unsupportedFirmwareVersion:
                    let alert = ErrorAlerts.buildGeneric(title: GDLocalizedString("devices.connect_headset.error_title"),
                                                         message: GDLocalizedString("devices.connect_headset.unsupported_firmware"),
                                                         dismissHandler: handler)
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    
                case DeviceError.failedConnection:
                    let alert = ErrorAlerts.buildGeneric(title: GDLocalizedString("devices.connect_headset.error_title"),
                                                         message: GDLocalizedString("devices.connect_headset.failed"),
                                                         dismissHandler: handler)
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    
                case DeviceError.unavailable:
                    var message = GDLocalizedString("devices.connect_headset.unavailable")
                    switch deviceType {
                    case .apple:
                        message = GDLocalizedString("devices.airpods_unavailable.alert.description")
                    case .sony:
                        message = "Sony linkbuds"
                    case .bose:
                        message = "Bose Frames"
                    case .generic:
                        message = "Generic device"
                    }
                                        
                    let alert = ErrorAlerts.buildGeneric(title: GDLocalizedString("devices.connect_headset.error_title"),
                                                         message: message,
                                                         dismissHandler: handler)
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    
                default:
                    self.state = .disconnected
                    self.connectedDevice = nil
                    return
                }
            }
        }
    }
}

// MARK: - DeviceManagerDelegate

extension DevicesViewController: DeviceManagerDelegate {
    
    func didConnectDevice(_ device: Device) {
        guard let calibratableDevice = device as? CalibratableDevice else {
            if let device = device as? HeadphoneMotionManagerWrapper, device.isFirstConnection {
                state = .completedPairing
            } else {
                state = .connected
            }
            return
        }
        
        switch calibratableDevice.calibrationState {
        case .needsCalibrating:
            state = .connected
            
            if let observer = calibrationObserver {
                NotificationCenter.default.removeObserver(observer)
                calibrationObserver = nil
            }
            
            calibrationObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationDidStart, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                self?.state = .calibrating
                
                if let observer = self?.calibrationObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.calibrationObserver = nil
                }
                
                self?.calibrationObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                    self?.state = .connected
                    
                    if let updateObserver = self?.calibrationUpdateObserver {
                        NotificationCenter.default.removeObserver(updateObserver)
                        self?.calibrationUpdateObserver = nil
                    }
                    
                    if let observer = self?.calibrationObserver {
                        NotificationCenter.default.removeObserver(observer)
                        self?.calibrationObserver = nil
                    }
                }
                
                self?.calibrationUpdateObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationUpdated, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                    // Calibration state has updated so rerender the UI as it may have changed
                    DispatchQueue.main.async { [weak self] in
                        self?.renderView()
                    }
                }
            }
            
        case .calibrating:
            state = .calibrating
            
            if let observer = calibrationObserver {
                NotificationCenter.default.removeObserver(observer)
                calibrationObserver = nil
            }
            
            calibrationObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                self?.state = .connected
                
                if let updateObserver = self?.calibrationUpdateObserver {
                    NotificationCenter.default.removeObserver(updateObserver)
                    self?.calibrationUpdateObserver = nil
                }
                
                if let observer = self?.calibrationObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.calibrationObserver = nil
                }
            }
            
            calibrationUpdateObserver = NotificationCenter.default.addObserver(forName: Notification.Name.ARHeadsetCalibrationUpdated, object: nil, queue: OperationQueue.main) { [weak self] (_) in
                // Calibration state has updated so rerender the UI as it may have changed
                DispatchQueue.main.async { [weak self] in
                    self?.renderView()
                }
            }
            
        case .calibrated:
            state = .connected
        }
    }
    
    func didDisconnectDevice(_ device: Device) {
        if AppContext.shared.deviceManager.devices.first != nil {
            // If the calibration UI was showing but the device disconnected, dismiss the view...
            guard state != .calibrating || !launchedAutomatically else {
                dismiss(animated: true, completion: nil)
                return
            }
            
            state = .paired
        } else {
            state = .disconnected
        }
    }
    
}
