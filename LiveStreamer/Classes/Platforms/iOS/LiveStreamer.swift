//
//  liveStreamer.swift
//  HaishinKit iOS
//
//  Created by st on 18/07/2018.
//  Copyright © 2018 James Lee. All rights reserved.
//

import UIKit
import AVFoundation

@available(iOSApplicationExtension 9.0, *)
open class LiveStreamer: NSObject, LiveStreamerControlInterface, LiveStreamerConfigureInterface {

    // MARK: Control Interface

    public weak var delegate: LiveStreamingDelegate?
    public weak var recorderDelegate: LiveRecorderDelegate?
    
    required public init(with view: GLHKView) {
        lfView = view
        rtmpStream = RTMPStream(connection: rtmpConnection)

        super.init()
        
        configureDefaultBroadcast()
    }
    
    public func startCapturingIfCan() -> Bool {
        guard lfView.streamLoaded == false else { return false }
        
        attachStream()
        addTapGesture()
        
        broadcastStatusForUser = .ready
        return true
    }

    public func startStreamingIfCan(with uri: String, _ streamName: String) -> Bool {
        guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return false }
        isUserWantConnect = true

        liveStreamAddress = LiveStreamAddress(uri: uri, streamName: streamName)
        
        startStreaming()
        
        broadcastStatusForUser = .startTrying
        return true
    }
    
    public func stopStreamingIfCan() -> Bool {
        if rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized { return false }
        isUserWantConnect = false
        
        stopStreaming()
        
        broadcastStatusForUser = .stop
        return true
    }

    public func pauseStreaming() {
        rtmpStream.togglePause()
        broadcastStatusForUser = .pause
    }
    
    public func startRecording() {
        guard rtmpStream.recordingState == .ready else { return }
        
        syncOrientation = false
        rtmpStream.startRecording()
    }
    
    public func stopRecording() {
        guard rtmpStream.recordingState == .recording else { return }
        
        // Prevent rotation while recording
        syncOrientation = true
        rtmpStream.stopRecording()
    }
 
    private var currentEffect: VisualEffect?
    public func applyEffectorIfCan(_ effector: VisualEffect) -> Bool {
        guard removeCurrentEffectorIfCan() == true else { return false }
        guard rtmpStream.registerEffect(video: effector) == true else { return false }
        currentEffect = effector
        return true
    }
    public func removeCurrentEffectorIfCan() -> Bool {
        guard let currentEffect: VisualEffect = currentEffect else { return true }
        return rtmpStream.unregisterEffect(video: currentEffect)
    }
    
    // MARK: Configure Interface
    
    // Changeable while recording/streaming
    public var cameraPosition: AVCaptureDevice.Position {
        get { return rtmpStream.mixer.videoIO.position }
        set (newValue) {
            guard rtmpStream.mixer.videoIO.position != newValue else { return }
            guard let newDevice = DeviceUtil.device(withPosition: newValue) else { return }
            rtmpStream.attachCamera(newDevice) { error in
                printLog(error)
            }
        }
    }
    
    private let qosDelegate = LiveStreamerRTMPStreamQoSDelegate()
    public var abrOn: Bool = true {
        didSet {
            if abrOn == true {
                rtmpStream.qosDelegate = qosDelegate
            } else {
                rtmpStream.qosDelegate = nil
                rtmpStream.videoSettings["bitrate"] = videoBitrate
            }
        }
    }
    
    public var videoMuted: Bool = false {
        didSet { (videoMuted == true) ? rtmpStream.toggleVideoPause() : rtmpStream.toggleVideoResume() }
    }
    public var audioMuted: Bool = false {
        didSet { (audioMuted == true) ? rtmpStream.toggleAudioPause() : rtmpStream.toggleAudioResume() }
    }

    public var videoBitrate: UInt32 = Preference.videoDefaultBitrate {
        didSet { rtmpStream.videoSettings["bitrate"] = videoBitrate }
    }
    public var audioBitrate: UInt32 = Preference.audioDefaultBitrate {
        didSet { rtmpStream.audioSettings["bitrate"] = audioBitrate }
    }
    
    public var maximumVideoBitrate: UInt32 = Preference.videoMaximumBitrate {
        didSet { rtmpStream.maximumBitrate = maximumVideoBitrate }
    }
    public var minimumVideoBitrate: UInt32 = Preference.videoMinimumBitrate {
        didSet { rtmpStream.minimumBitrate = minimumVideoBitrate }
    }
    
    public var zoomRate: Float = 1.0 {
        didSet { rtmpStream.setZoomFactor(CGFloat(zoomRate), ramping: true, withRate: 5.0) }
    }
    
    public var torch: Bool = false {
        didSet { rtmpStream.torch = torch }
    }
    
    public var torchModeSupported: Bool {
        get { return rtmpStream.isTorchModeSupported() }
    }

    public var sampleRate: Double = Preference.sampleRate {
        didSet {
            rtmpStream.audioSettings = [
                "sampleRate": sampleRate
            ]
        }
    }
    
    public var sessionPreset: AVCaptureSession.Preset = Preference.sessionPreset {
        didSet {
            guard let currentDevice: AVCaptureDevice = DeviceUtil.device(withPosition: cameraPosition) else { return }
            let supportedPreset: AVCaptureSession.Preset = currentDevice.supportedPreset(sessionPreset)
            rtmpStream.captureSettings["sessionPreset"] = supportedPreset.rawValue
            
            captureSettings = [
                // for 4:3 resolution
                //"sessionPreset": AVCaptureSession.Preset.photo.rawValue,
                
                "sessionPreset": sessionPreset,
                "continuousAutofocus": true,
                "continuousExposure": true
            ]
        }
    }
    
    public var videoSize: CGSize = Preference.videoSize {
        didSet { setScreenRatio(with: videoSize) }
    }
    public var recordFileName: String = Preference.recordFileName {
        didSet { rtmpStream.mixer.recorder.fileName = recordFileName }
    }
    public var videoFPS: Float = Preference.defaultFPS {
        didSet { rtmpStream.captureSettings["fps"] = videoFPS }
    }
    
    public var syncOrientation: Bool = true {
        didSet { rtmpStream.syncOrientation = syncOrientation }
    }
 
    // MARK: Retry Protocol
    
    public var broadcastTimeout: TimeInterval = 150
    public var retryConnectInterval: TimeInterval = 4
    public var unableTimeCount: TimeInterval = 0
  
    // MARK: Configure
    
    private func configureDefaultBroadcast() {
        configureRecorder()
        
        videoSize = Preference.videoSize
        sessionPreset = Preference.sessionPreset
        sampleRate = Preference.sampleRate
        videoBitrate = Preference.videoDefaultBitrate
        audioBitrate = Preference.audioDefaultBitrate
        maximumVideoBitrate = Preference.videoMaximumBitrate
        minimumVideoBitrate = Preference.videoMinimumBitrate
        audioMuted = false
        zoomRate = 1.0
        abrOn = true
        torch = false
        syncOrientation = true

        registerFPSObserver()
    }
    private func configureRecorder() {
        rtmpStream.mixer.recorder.outerDelegate = self
        recordFileName = Preference.recordFileName
    }
    
    private func setScreenRatio(with size: CGSize) {
        var longerSize: CGFloat = 0.0
        var shorterSize: CGFloat = 0.0
        
        if size.width > size.height {
            longerSize = size.width
            shorterSize = size.height
        } else {
            longerSize = size.height
            shorterSize = size.width
        }
        
        if rtmpStream.orientation == .portrait || rtmpStream.orientation == .portraitUpsideDown {
            rtmpStream.videoSettings = [
                "width": shorterSize,
                "height": longerSize
            ]
            
        } else {
            rtmpStream.videoSettings = [
                "width": longerSize,
                "height": shorterSize
            ]
        }
    }
    
    // Unchangeable while recording/streaming
    private var captureSettings: [String: Any] = [:] {
        didSet {
            guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return }
            rtmpStream.captureSettings = captureSettings
        }
    }

    // MARK: Control
    
    private let rtmpConnection: RTMPConnection = RTMPConnection()
    private let rtmpStream: RTMPStream
    private var liveStreamAddress: LiveStreamAddress?
    
    private(set) var isUserWantConnect = false

    private func attachStream() {
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            printLog(error)
        }
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: cameraPosition)) { error in
            printLog(error)
        }
        
        lfView.attachStream(rtmpStream)
    }

    private func startRTMPConnection(with uri: String?) {
        guard let uri = uri else { return }
        // Need time to prepare service. will callback at rtmpStatusHandler()
        rtmpConnection.start(uri)
    }
    private func publishRTMPConnection(with name: String?, type: RTMPStream.HowToPublish) {
        rtmpStream.publish(name, type: type)
    }
    private func stopRTMPConnection() {
        rtmpConnection.stop()
    }
 
    private func startStreaming() {
        startRetryConnectionTimer(timeInterval: retryConnectInterval)
        
        setScreenRatio(with: videoSize)
        // Prevent rotation while recording
        syncOrientation = false

        addRTMPObserver()
        startRTMPConnection(with: liveStreamAddress?.uri)
    }
    
    private func stopStreaming() {
        stopRetryConnectionTimer()
        
        syncOrientation = true

        stopRTMPConnection()
        removeRTMPObserver()
    }
    
    private func addRTMPObserver() {
        //rtmpConnection.addEventListener(Event.SYNC, selector: #selector(rtmpStatusHandler), observer: self)
        //rtmpConnection.addEventListener(Event.EVENT, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(Event.IO_ERROR, selector: #selector(rtmpIOErrorHandler), observer: self)
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
    }
    private func removeRTMPObserver() {
        //rtmpConnection.removeEventListener(Event.SYNC, selector: #selector(rtmpStatusHandler), observer: self)
        //rtmpConnection.removeEventListener(Event.EVENT, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(Event.IO_ERROR, selector: #selector(rtmpIOErrorHandler), observer: self)
        rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
    }
 
    private func addTapGesture() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(tapScreen(_:)))
        lfView.addGestureRecognizer(singleTap)
    }
 
    private var broadcastStatusForUser: BroadcastStatusForUser = .initialize {
        didSet { delegate?.broadcastStatusForUserWith(code: broadcastStatusForUser.rawValue) }
    }
    
    private let lfView: GLHKView
 
    deinit {
        printLog("deinit")
        timer = nil
        _ = stopStreamingIfCan()
        stopRecording()
        rtmpStream.close()
        rtmpStream.dispose()
        unRegisterFPSObserver()
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentFPS" {
            delegate?.fpsChanged(fps: Float(rtmpStream.currentFPS))
        }
    }
    
    private func registerFPSObserver() {
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
    }
    private func unRegisterFPSObserver() {
        rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
    }
 
    @objc func tapScreen(_ gesture: UIGestureRecognizer) {
        guard let gestureView = gesture.view, gesture.state == .ended else { return }
        let touchPoint: CGPoint = gesture.location(in: gestureView)
        let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                                               y: touchPoint.y/gestureView.bounds.size.height)
        rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
    }
    
    // MARK: Auto retry
    
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            guard let timer: Timer = timer else { return }
            RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        }
    }
    private func startRetryConnectionTimer(timeInterval: TimeInterval) {
        timer = Timer(timeInterval: timeInterval, target: self, selector: #selector(on(timer:)), userInfo: nil, repeats: true)
    }
    private func stopRetryConnectionTimer() {
        timer = nil
    }
 
    func setBroadcastStatusForUserToError() {
        if broadcastStatusForUser == .startTrying || broadcastStatusForUser == .startFailed{
            broadcastStatusForUser = .startFailed
        } else {
            broadcastStatusForUser = .failed
        }
    }
    
    func setBroadcastStatusForUserToFailed() {
        if broadcastStatusForUser == .startTrying || broadcastStatusForUser == .startFailed{
            broadcastStatusForUser = .startFailed
            startRetryConnectionTimer(timeInterval: retryConnectInterval)
        } else {
            broadcastStatusForUser = .failed
        }
    }
    
    func setBroadcastStatusForUserToFailedTimeout() {
        if broadcastStatusForUser == .startTrying || broadcastStatusForUser == .startFailed {
            broadcastStatusForUser = .startFailed
            startRetryConnectionTimer(timeInterval: retryConnectInterval)
        } else {
            broadcastStatusForUser = .failedTimeout
            startRetryConnectionTimer(timeInterval: retryConnectInterval)
        }
    }
    
    func setBroadcastStatusForUserToClose() {
        if isUserWantConnect == true {
            broadcastStatusForUser = .failed
            startRetryConnectionTimer(timeInterval: retryConnectInterval)
        } else {
            broadcastStatusForUser = .stop
        }
    }
    
    func retryConnectionIfNeeded() {
        guard isUserWantConnect == true else { return }
        guard rtmpConnection.connected == false else { return }
        guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return }
        // If we try to start socket connection rapidly, problem occur. So we have disconnect properly before reconnect
        
        if let interval = timer?.timeInterval {
            unableTimeCount = unableTimeCount + interval
        }
        
        guard unableTimeCount < broadcastTimeout else {
            unableTimeCount = 0
            stopStreaming()
            broadcastStatusForUser = .terminated
            return
        }
        
        if broadcastStatusForUser == .startTrying || broadcastStatusForUser == .startFailed{
            broadcastStatusForUser = .startTrying
        } else {
            broadcastStatusForUser = .failedRetying
        }
        
        startRTMPConnection(with: liveStreamAddress?.uri )
    }
    
    @objc private func on(timer: Timer) {
        retryConnectionIfNeeded()
    }
    
    // MARK: Handler
    
    @objc func rtmpIOErrorHandler(_ notification: Notification) {
        // Socket timeout. when timed out, reconnection is not working
        
        // Close stream for reconnect
        stopRTMPConnection()

        setBroadcastStatusForUserToFailedTimeout()
    }
    
    @objc func rtmpStatusHandler(_ notification: Notification) {
        printLog("rtmpStatusHandler \(notification)")
        let event: Event = Event.from(notification)
        guard let data: ASObject = event.data as? ASObject, let code: String = data["code"] as? String else { return }
        
        delegate?.broadcastStatusWith(code: code)
        
        switch code {
            
        case RTMPConnection.Code.connectSuccess.rawValue:
            
            publishRTMPConnection(with: liveStreamAddress?.streamName, type: .live)
            
            broadcastStatusForUser = .start
            stopRetryConnectionTimer()
            unableTimeCount = 0
            break
            
        case RTMPConnection.Code.connectNetworkChange.rawValue:
            
            break
            
        case RTMPConnection.Code.connectIdleTimeOut.rawValue:
            
            setBroadcastStatusForUserToFailedTimeout()
            break
            
        case RTMPConnection.Code.connectRejected.rawValue:
            // Server is not yet started or needs authentication
            
            break
            
        case RTMPConnection.Code.connectFailed.rawValue:
            // If handshake is failed before deinitconnect, connectFailed call. Or connectClosed call
            
            setBroadcastStatusForUserToFailed()
            break
            
        case RTMPConnection.Code.connectError.rawValue:
            // If handshake is failed before deinitconnect, connectFailed call. Or connectClosed call
            
            setBroadcastStatusForUserToError()
            break
            
        case RTMPConnection.Code.connectClosed.rawValue:
            // Server is closing
            
            setBroadcastStatusForUserToClose()
            break
            
        default:
            break
        } 
    }
}
