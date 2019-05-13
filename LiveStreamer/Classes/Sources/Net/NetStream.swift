import CoreImage
import Foundation
import AVFoundation

protocol NetStreamDrawable: class {
    #if os(iOS) || os(macOS)
    var orientation: AVCaptureVideoOrientation { get set }
    var position: AVCaptureDevice.Position { get set }
    #endif
    
    func draw(image: CIImage)
    func attachStream(_ stream: NetStream?)
}

// MARK: -
public class NetStream: NSObject {
    public private(set) var mixer: AVMixer = AVMixer()
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    public let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()
    
    deinit {
        metadata.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    public var metadata: [String: Any?] = [: ]
    
    public var context: CIContext? {
        get { return mixer.videoIO.context }
        set { mixer.videoIO.context = newValue }
    }
    
    #if os(iOS) || os(macOS)
    public var torch: Bool {
        get {
            var torch: Bool = false
            ensureLockQueue {
                torch = self.mixer.videoIO.torch
            }
            return torch
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.torch = newValue
            }
        }
    }
    
    public func isTorchModeSupported() -> Bool {
        guard let device: AVCaptureDevice = (mixer.videoIO.input as? AVCaptureDeviceInput)?.device else { return false }
        return device.isTorchModeSupported(.on) 
    }
    
    #endif
    
    #if os(iOS)
    public var syncOrientation: Bool = false {
        didSet {
            guard syncOrientation != oldValue else { return }
            if syncOrientation == true {
                NotificationCenter.default.addObserver(self, selector: #selector(on), name: UIDevice.orientationDidChangeNotification, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            }
        }
    }
    #endif
    
    public var audioSettings: [String: Any] {
        get {
            var audioSettings: [String: Any]!
            ensureLockQueue {
                audioSettings = self.mixer.audioIO.encoder.dictionaryWithValues(forKeys: AACEncoder.supportedSettingsKeys)
            }
            return audioSettings
        }
        set {
            ensureLockQueue {
                self.mixer.audioIO.encoder.setValuesForKeys(newValue)
            }
        }
    }
    
    public var videoSettings: [String: Any] {
        get {
            var videoSettings: [String: Any]!
            ensureLockQueue {
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValues(forKeys: H264Encoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            ensureLockQueue {
                self.mixer.videoIO.encoder.setValuesForKeys(newValue)
            }
        }
    }
    
    public var captureSettings: [String: Any] {
        get {
            var captureSettings: [String: Any]!
            ensureLockQueue {
                captureSettings = self.mixer.dictionaryWithValues(forKeys: AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            ensureLockQueue {
                self.mixer.setValuesForKeys(newValue)
            }
        }
    }
    
    public var recorderSettings: [AVMediaType: [String: Any]] {
        get {
            var recorderSettings: [AVMediaType: [String: Any]]!
            ensureLockQueue {
                recorderSettings = self.mixer.recorder.outputSettings
            }
            return recorderSettings
        }
        set {
            ensureLockQueue {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }
    
    #if os(iOS) || os(macOS)
    public func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        ensureLockQueue {
            do {
                try self.mixer.videoIO.attachCamera(camera)
                self.mixer.videoIO.setSampleBufferDelegate()
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    public func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) {
        ensureLockQueue {
            do {
                try self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
                self.mixer.audioIO.setSampleBufferDelegate()
            } catch let error as NSError {
                onError?(error)
            }
        }
    }
    
    public func setPointOfInterest(_ focus: CGPoint, exposure: CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }
    #endif
    
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: AVMediaType, options: [NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.appendSampleBuffer(sampleBuffer)
            }
        case .video:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.appendSampleBuffer(sampleBuffer)
            }
        default:
            break
        }
    }
    
    public func registerEffect(video effect: VisualEffect) -> Bool {
        return mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.registerEffect(effect)
        }
    }
    
    public func unregisterEffect(video effect: VisualEffect) -> Bool {
        return mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.unregisterEffect(effect)
        }
    }
    
    public func dispose() {
        lockQueue.async {
            self.mixer.dispose()
        }
    }
    
    #if os(iOS)
    @objc private func on(uiDeviceOrientationDidChange: Notification) {
        guard let orientation: AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: uiDeviceOrientationDidChange) else { return }
        self.orientation = orientation
    }
    #endif
    
    func ensureLockQueue(callback: () -> Void) {
        if DispatchQueue.getSpecific(key: NetStream.queueKey) == NetStream.queueValue {
            callback()
        } else {
            lockQueue.sync {  // Will cause deadlock if lockQueue is current queue. So we checked current queue as above
                callback()
            }
        }
    }
}
