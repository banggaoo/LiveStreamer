//
//  liveStreamer.swift
//  HaishinKit iOS
//
//  Created by st on 18/07/2018.
//  Copyright © 2018 James Lee. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

struct LiveStreamAddress {
    // If you want to use singleton
    //static var defaultInstance: Preference = Preference()
    
    // uri is like "rtmp://test:test@192.168.11.15/live/01",  "rtmp://1b6cf5.entrypoint.cloud.wowza.com/app-6f91/188e39fc"
    public var uri: String
    public var streamName: String  // "188e39fc"
}


class LiveStreamerRecorderDelegate: DefaultAVMixerRecorderDelegate {
    override func didFinishWriting(_ recorder: AVMixerRecorder) {
        
        guard let writer: AVAssetWriter = recorder.writer else { return }
        
        // Store local video to photo library and remove from document folder
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { (_, error) -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch let error {
                print(error)
            }
        })
    }
    
    override func didStartRunning(_ recorder: AVMixerRecorder) {
        
    }
}

public protocol LiveStreamingDelegate: class {

    func broadcastStatusWith(code: String)
    func fpsChanged(fps: Float)
}

public class LiveStreamer: NSObject {
    var rtmpConnection: RTMPConnection = RTMPConnection()
    var rtmpStream: RTMPStream!
    var currentEffect: VisualEffect?
    var liveStreamAddress: LiveStreamAddress = LiveStreamAddress(uri: "", streamName: "")
    
   public weak var delegate: LiveStreamingDelegate?

    var delegations: [String: AnyObject] = [:]

    // CamView
    var lfView: GLHKView
    
    // Changeable while recording/streaming
    var _cameraPosition: AVCaptureDevice.Position = .back
    open var cameraPosition: AVCaptureDevice.Position {

        get { return _cameraPosition }
        
        set {
            
            if _cameraPosition == newValue { return }

            rtmpStream.attachCamera(DeviceUtil.device(withPosition: newValue)) { error in
                print(error)
                return
            }
            _cameraPosition = newValue
        }
    }
    
    open var videoBitrate: UInt32 = 32 * 1024 { didSet { rtmpStream.videoSettings["bitrate"] = videoBitrate } }
    open var audioBitrate: UInt32 = 160 * 1024 { didSet { rtmpStream.audioSettings["bitrate"] = audioBitrate } }
    
    open var zoomRate: Float = 1.0 { didSet { rtmpStream.setZoomFactor(CGFloat(zoomRate), ramping: true, withRate: 5.0) } }

    open var torch: Bool = false { didSet { rtmpStream.torch = torch } }

    // Unchangeable while recording/streaming
    var captureSettings: [String: Any] = [:] { didSet { rtmpStream.captureSettings = captureSettings } }
    
    var sampleRate: Double = 44_100 {
        
        didSet {
            
            rtmpStream.audioSettings = [
                "sampleRate": sampleRate
            ]
        }
    }

    open var videoSize: CGSize = CGSize(width: CGFloat(720), height: CGFloat(1280)) {
        
        didSet {
            
            rtmpStream.videoSettings = [
                "width": videoSize.width,
                "height": videoSize.height
            ]
        }
    }
 
    // If you want to keep movie file in document folder, remove FileManager.default.removeItem in LiveStreamerRecorderDelegate
    open var recordFileName: String = "Movie" { didSet { rtmpStream.mixer.recorder.fileName = recordFileName } }
    
    open var videoFPS: Float = 24.0 { didSet { rtmpStream.captureSettings["fps"] = videoFPS } }

    
    public init(view: GLHKView) {
        print("init(view: GLHKView")
        lfView = view
        
        super.init()

        prepareBroadcast()
    }
    
    func prepareBroadcast() {
        
        //activeAudioSession()
        
        createRTMPStream()
        
        configureBroadcast()

        attachCamera()
    }
    /*
    func activeAudioSession() {
        
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredSampleRate(44_100)
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .allowBluetooth)
            try session.setMode(AVAudioSessionModeDefault)
            try session.setActive(true)
        } catch let error {

            print("Unexpected error: \(error).")
        }
    }*/
    
    func createRTMPStream() {

        rtmpStream = RTMPStream(connection: rtmpConnection)
    }
    
    func configureBroadcast() {

        rtmpStream.syncOrientation = true
        
        captureSettings = [
            // for 4:3 resolution
            //"sessionPreset": AVCaptureSession.Preset.photo.rawValue,

            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true
        ]
        
        videoSize = CGSize(width: 720, height: 1280)
        
        sampleRate = 44_100
        
        rtmpStream.mixer.recorder.delegate = LiveStreamerRecorderDelegate()
        
        registerFPSObserver()
    }
    
    func attachCamera() {
        
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
        
        disableMedia()
    }
    
    public func disableMedia() {
        
        stopStreaming()
        stopRecording()
        
        unRegisterFPSObserver()
        
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

        // Prevent rotation while recording
        rtmpStream.syncOrientation = !isReady
    }
    
    open func registerFPSObserver() {
        
        guard let liveStreamer: AnyObject = delegations["currentFPS"], liveStreamer is LiveStreamer else {
            
            delegations["currentFPS"] = self
            
            self.rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
            
            return
        }
    }

    open func unRegisterFPSObserver() {
        
        if let liveStreamer: AnyObject = delegations["currentFPS"], liveStreamer is LiveStreamer {

            delegations.removeValue(forKey: "currentFPS")
            
            self.rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        }
    }
 
    open func startRecodring() {
        
        if (rtmpStream.recordingState == .recording) { return }

        readyForBroadcast(isReady: true)
        
        rtmpStream.startRecording()
    }
    
    open func stopRecording() {
        
        readyForBroadcast(isReady: false)

        rtmpStream.stopRecording()
    }
    
    open func startStreaming(uri: String, streamName: String) {
        
        liveStreamAddress.uri = uri
        liveStreamAddress.streamName = streamName
        
        readyForBroadcast(isReady: true)
        
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.connect(liveStreamAddress.uri)
        // Need time to prepare service. will callback at rtmpStatusHandler()
    }
 
    open func stopStreaming() {
        
        readyForBroadcast(isReady: false)

        rtmpConnection.close()
        rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
    }
    
    open func pauseStreaming() {
    
        rtmpStream.togglePause()
    }
    
    
    @objc func rtmpStatusHandler(_ notification: Notification) {
        print("rtmpStatusHandler\(notification)")
        let e: Event = Event.from(notification)
        if let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String {
            
            delegate?.broadcastStatusWith(code: code)

            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                
                rtmpStream!.publish(liveStreamAddress.streamName, type:.live)
                break
                
            case RTMPConnection.Code.connectNetworkChange.rawValue, RTMPConnection.Code.connectClosed.rawValue:

                readyForBroadcast(isReady: false)
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
