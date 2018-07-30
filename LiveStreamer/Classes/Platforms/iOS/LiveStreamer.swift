//
//  liveStreamer.swift
//  HaishinKit iOS
//
//  Created by st on 18/07/2018.
//  Copyright © 2018 James Lee. All rights reserved.
//

import UIKit
import AVFoundation

struct LiveStreamAddress {
    // If you want to use singleton
    //static var defaultInstance: Preference = Preference()
    
    // uri is like "rtmp://test:test@192.168.11.15/live",  "rtmp://1b6cf5.entrypoint.cloud.wowza.com/app-6f91"
    public var uri: String
    public var streamName: String  // ex : "188e39fc"
}

class LiveStreamerRTMPStreamQoSDelegate: RTMPStreamDelegate {
    
    // detect upload insufficent BandWidth
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {

        if var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 {

            videoBitrate = UInt32(videoBitrate / 2)

            if videoBitrate < stream.minimumBitrate {
                videoBitrate = stream.minimumBitrate
            }
            
            stream.videoSettings["bitrate"] = videoBitrate
        }
    }
    
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {

        if var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 {

            videoBitrate = UInt32(Double(videoBitrate) + 50 * 1024)

            if videoBitrate > stream.maximumBitrate {
                
                videoBitrate = stream.maximumBitrate
            }
            
            stream.videoSettings["bitrate"] = videoBitrate
        }
    }
    
    func clear() {

    }
}


extension LiveStreamer: AVMixerRecorderOuterDelegate {
    
    public func didFinishWriting(_ recorder: AVMixerRecorder) {
        
        recorderDelegate?.didFinishWriting(recorder)
    }
    
    public func didStartRunning(_ recorder: AVMixerRecorder) {
        
        recorderDelegate?.didStartRunning(recorder)
    }
}

public protocol LiveStreamingDelegate: class {
    
    func broadcastStatusWith(code: String)
    func fpsChanged(fps: Float)
}

public protocol LiveRecorderDelegate: class {
    
    func didFinishWriting(_ recorder: AVMixerRecorder)
    func didStartRunning(_ recorder: AVMixerRecorder)
}

@available(iOSApplicationExtension 9.0, *)
public class LiveStreamer: NSObject {
    var rtmpConnection: RTMPConnection = RTMPConnection()
    var rtmpStream: RTMPStream!
    var currentEffect: VisualEffect?
    var liveStreamAddress: LiveStreamAddress = LiveStreamAddress(uri: "", streamName: "")
    
    var isUserWantConnect: Bool = false
    var isConnectionFailed: Bool = false

    public weak var delegate: LiveStreamingDelegate?
    public weak var recorderDelegate: LiveRecorderDelegate?

    var delegations: [String: AnyObject] = [:]

    // CamView
    var lfView: GLHKView
    
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            if let timer: Timer = timer {
                RunLoop.main.add(timer, forMode: .commonModes)
            }
        }
    }

    // Changeable while recording/streaming
    var _cameraPosition: AVCaptureDevice.Position = .front
    open var cameraPosition: AVCaptureDevice.Position {

        get { return _cameraPosition }
        
        set {
            
            if _cameraPosition == newValue { return }
 
            if let newDevice: AVCaptureDevice = DeviceUtil.device(withPosition: newValue) {
                
                let supportedPreset: AVCaptureSession.Preset = newDevice.supportedPreset(sessionPreset)

                rtmpStream.captureSettings["sessionPreset"] = supportedPreset.rawValue

                rtmpStream.attachCamera(newDevice) { error in
                    print(error)
                    return
                }
                _cameraPosition = newValue
            }
        }
    }
    
    open var videoBitrate: UInt32 = 1024 * 1024 { didSet { rtmpStream.videoSettings["bitrate"] = videoBitrate } }
    open var audioBitrate: UInt32 = 128 * 1024 { didSet { rtmpStream.audioSettings["bitrate"] = audioBitrate } }
    
    open var zoomRate: Float = 1.0 { didSet { rtmpStream.setZoomFactor(CGFloat(zoomRate), ramping: true, withRate: 5.0) } }

    open var torch: Bool = false { didSet { rtmpStream.torch = torch } }

    open var abrOn: Bool = true {
        
        didSet {
            
            objc_sync_enter(self)
            rtmpStream.qosDelegate = nil
            objc_sync_exit(self)
            
            if abrOn {
                
                rtmpStream.qosDelegate = LiveStreamerRTMPStreamQoSDelegate()
                
            }else{
                
                rtmpStream.videoSettings["bitrate"] = videoBitrate
            }
        }
    }

    // Unchangeable while recording/streaming
    var captureSettings: [String: Any] = [:] { didSet { rtmpStream.captureSettings = captureSettings } }
    
    open var sampleRate: Double = 44_100 {
        
        didSet {
            
            rtmpStream.audioSettings = [
                "sampleRate": sampleRate
            ]
        }
    }

    var _sessionPreset: AVCaptureSession.Preset = AVCaptureSession.Preset.hd1280x720
    open var sessionPreset: AVCaptureSession.Preset {

        get { return _sessionPreset }
        
        set {

            if let currentDevice: AVCaptureDevice = DeviceUtil.device(withPosition: cameraPosition) {

                let supportedPreset: AVCaptureSession.Preset = currentDevice.supportedPreset(newValue)
                
                rtmpStream.captureSettings["sessionPreset"] = supportedPreset.rawValue
                
                _sessionPreset = supportedPreset
            }
        }
    }

    var _videoSize: CGSize = CGSize(width: CGFloat(720), height: CGFloat(1280))
    open var videoSize: CGSize {
        
        get { return _videoSize }
        
        set {
            
            guard rtmpStream.recordingState == .notRecording else { return }
            
            guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return }

            _videoSize = newValue
        }
    }
 
    open var recordFileName: String = "Movie" { didSet { rtmpStream.mixer.recorder.fileName = recordFileName } }
    
    open var videoFPS: Float = 30.0 { didSet { rtmpStream.captureSettings["fps"] = videoFPS } }
    
    
    public init(view: GLHKView) {
        print("init(view: GLHKView")
        lfView = view
        
        super.init()

        rtmpStream = RTMPStream(connection: rtmpConnection)

        configureBroadcast()
    }
    
    @available(iOSApplicationExtension 9.0, *)
    func configureBroadcast() {

        rtmpStream.mixer.recorder.outerDelegate = self
        
        rtmpStream.mixer.recorder.fileName = recordFileName

        captureSettings = [
            // for 4:3 resolution
            //"sessionPreset": AVCaptureSession.Preset.photo.rawValue,

            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true
        ]
        
        videoSize = CGSize(width: 1280, height: 720)
        
        sampleRate = 44_100
        
        rtmpStream.syncOrientation = true
        
        abrOn = true
        
        registerFPSObserver()
    }
    
    public func startCapturing() {
        
        guard !(lfView.streamLoaded) else { return }
        
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            print(error)
        }
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: cameraPosition)) { error in
            print(error)
        }
        
        lfView.attachStream(rtmpStream)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(self.tapScreen(_:)))
        lfView.addGestureRecognizer(singleTap)
    }
    
    deinit {
        
        timer = nil

        disableMedia()
    }
    
    public func disableMedia() {
        
        stopStreaming()
        stopRecording()
        
        unRegisterFPSObserver()
        
        rtmpStream.close()
        rtmpStream.dispose()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "currentFPS" {
            
            delegate?.fpsChanged(fps: Float(rtmpStream.currentFPS))
        }
    }

    open func isTorchModeSupported() -> Bool {
        
        return rtmpStream.isTorchModeSupported()
    }
    
    func readyForBroadcast(isReady: Bool) {

        if isReady {
            // Set video size ratio
            rtmpStream.videoSettings = [
                "width": videoSize.width,
                "height": videoSize.height
            ]
            
            rtmpStream.syncOrientation = false
        }else{
            
            guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return }
            
            guard rtmpStream.recordingState == .notRecording else { return }

            // Prevent rotation while recording
            rtmpStream.syncOrientation = true
        }
    }
    
    open func registerFPSObserver() {
        
        guard let liveStreamer: AnyObject = delegations["currentFPS"], liveStreamer is LiveStreamer else { return }
        
        delegations["currentFPS"] = self
        
        self.rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
    }

    open func unRegisterFPSObserver() {
        
        if let liveStreamer: AnyObject = delegations["currentFPS"], liveStreamer is LiveStreamer {

            delegations.removeValue(forKey: "currentFPS")
            
            self.rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        }
    }
 
    open func startRecodring() {
        
        guard rtmpStream.recordingState == .notRecording else { return }

        readyForBroadcast(isReady: true)
        
        rtmpStream.startRecording()
    }
    
    open func stopRecording() {
        
        guard rtmpStream.recordingState == .recording else { return }

        readyForBroadcast(isReady: false)

        rtmpStream.stopRecording()
    }
    
    open func startStreaming(uri: String, streamName: String) {

        guard rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized else { return }

        liveStreamAddress.uri = uri
        liveStreamAddress.streamName = streamName
        
        isUserWantConnect = true
        isConnectionFailed = false
        
        readyForBroadcast(isReady: true)
        
        timer = Timer(timeInterval: 3.0, target: self, selector: #selector(on(timer:)), userInfo: nil, repeats: true)

        //rtmpConnection.addEventListener(Event.SYNC, selector: #selector(rtmpStatusHandler), observer: self)
        //rtmpConnection.addEventListener(Event.EVENT, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(Event.IO_ERROR, selector: #selector(rtmpIOErrorHandler), observer: self)
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.start(liveStreamAddress.uri)
        // Need time to prepare service. will callback at rtmpStatusHandler()
    }
 
    open func stopStreaming() {
        
        guard !(rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized) else { return }

        isUserWantConnect = false
        
        readyForBroadcast(isReady: false)

        timer = nil

        rtmpConnection.stop()
        //rtmpConnection.removeEventListener(Event.SYNC, selector: #selector(rtmpStatusHandler), observer: self)
        //rtmpConnection.removeEventListener(Event.EVENT, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(Event.IO_ERROR, selector: #selector(rtmpIOErrorHandler), observer: self)
        rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
    }
    
    open func pauseStreaming() {
    
        rtmpStream.togglePause()
    }
    
    @objc private func on(timer: Timer) {
        // Check connection is need to retry
        
        print("on\(isUserWantConnect)\(isConnectionFailed)\(rtmpConnection.connected)")

        if isUserWantConnect, isConnectionFailed {
            
            print("rtmpStream.readyState\(rtmpStream.readyState)")

            if rtmpConnection.connected {
                // Need to close the connection for reconnect
                
                rtmpConnection.close()
                return
            }
            
            if rtmpStream.readyState == .closed || rtmpStream.readyState == .initialized {
                
                isConnectionFailed = false
                rtmpConnection.start(liveStreamAddress.uri)
            }
        }
    }
    
    
    @objc func rtmpIOErrorHandler(_ notification: Notification) {
        print("rtmpIOErrorHandler\(notification)")
        // Socket timeout. when timed out, reconnection is not working

        isConnectionFailed = true
    }
    
    @objc func rtmpStatusHandler(_ notification: Notification) {
        print("rtmpStatusHandler\(notification)")
        let e: Event = Event.from(notification)
        if let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String {
            
            delegate?.broadcastStatusWith(code: code)

            switch code {
                
            case RTMPConnection.Code.connectSuccess.rawValue:
                
                isConnectionFailed = false
                
                rtmpStream!.publish(liveStreamAddress.streamName, type:.live)
                break
                
            case RTMPConnection.Code.connectNetworkChange.rawValue:

                break
                
            case RTMPConnection.Code.connectIdleTimeOut.rawValue:

                isConnectionFailed = true
                break
                
            case RTMPConnection.Code.connectFailed.rawValue:
                
                isConnectionFailed = true
                break
                
            case RTMPConnection.Code.connectRejected.rawValue:
                // Server is not yet started or needs authentication
                
                isConnectionFailed = true
                break
                
            case RTMPConnection.Code.connectClosed.rawValue:
                // Server is closing

                isConnectionFailed = false
                break
                
            default:
                break
            }
        }
    }

    @objc func tapScreen(_ gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view, gesture.state == .ended {
            let touchPoint: CGPoint = gesture.location(in: gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                                                   y: touchPoint.y/gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }

    open func apply(effector: VisualEffect) {
        // Kind of effector : MonochromeEffect(), PronamaEffect(), CurrentTimeEffect()

        removeCurrentEffector()
        
        _ = rtmpStream.registerEffect(video: effector)
        currentEffect = effector
    }
    
    open func removeCurrentEffector() {
        
        if let currentEffect: VisualEffect = currentEffect {
            _ = rtmpStream.unregisterEffect(video: currentEffect)
        }
    }
}
