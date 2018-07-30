import LiveStreamer
import UIKit
import AVFoundation
import Photos


extension LiveViewController: LiveStreamingDelegate {
    
    func broadcastStatusWith(code: String) {
        
        switch code {
            
        case RTMPConnection.Code.connectSuccess.rawValue:
            
            DispatchQueue.main.async {
                
                self.publishButton?.setTitle("■", for: [])
                
                UIApplication.shared.isIdleTimerDisabled = true
            }
            break
            
        case RTMPConnection.Code.connectNetworkChange.rawValue:
            
            break
            
        default:
            
            DispatchQueue.main.async {

                self.publishButton?.setTitle("●", for: [])

                UIApplication.shared.isIdleTimerDisabled = false
                
                self.publishButton?.isSelected = !((self.publishButton?.isSelected)!)
            }
            break
        }
    }
    
    func fpsChanged(fps: Float) {
        
        if Thread.isMainThread {
            
            currentFPSLabel?.text = "FPS : \(fps)"
        }
    }
}

extension LiveViewController: LiveRecorderDelegate {

    public func didFinishWriting(_ recorder: AVMixerRecorder) {
        
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
    
    public func didStartRunning(_ recorder: AVMixerRecorder) {
        
    }
}

final class LiveViewController: UIViewController {
    
    var liveStreamer: LiveStreamer!
    
    @IBOutlet var lfView: GLHKView!  // camera
    
    @IBOutlet var currentFPSLabel: UILabel?
    @IBOutlet var publishButton: UIButton?
    @IBOutlet var pauseButton: UIButton?
    @IBOutlet var videoBitrateLabel: UILabel?
    @IBOutlet var videoBitrateSlider: UISlider?
    @IBOutlet var audioBitrateLabel: UILabel?
    @IBOutlet var zoomSlider: UISlider?
    @IBOutlet var audioBitrateSlider: UISlider?
    @IBOutlet var fpsControl: UISegmentedControl?
    @IBOutlet var effectSegmentControl: UISegmentedControl?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        liveStreamer = LiveStreamer(view: lfView)

        liveStreamer.delegate = self
        liveStreamer.recorderDelegate = self

        // Please check suitable media setting for streaming
        // http://jira.stunitas.com:8080/secure/attachment/10505/IMG_1209.PNG

        // Please be sure your device`s camera support resolution with front/back camera both. If you set higher resolution, camera doesn't work properly
        liveStreamer.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        liveStreamer.videoSize = CGSize(width: 1920, height: 1080)

        liveStreamer.videoFPS = 30
        liveStreamer.videoBitrate = 1024 * 1024
        liveStreamer.audioBitrate = 128 * 1024

        liveStreamer.sampleRate = 44_100
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // It is better to run startCapturing method after view is appeared
        liveStreamer.startCapturing()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        

    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
 
    @IBAction func rotateCamera(_ sender: UIButton) {
 
        let position: AVCaptureDevice.Position = liveStreamer.cameraPosition == .back ? .front : .back
        liveStreamer.cameraPosition = position
    }

    @IBAction func toggleTorch(_ sender: UIButton) {
        
        liveStreamer.torch = !(liveStreamer.torch)
    }

    @IBAction func on(slider: UISlider) {
        if slider == audioBitrateSlider {
            audioBitrateLabel?.text = "audio \(Int(slider.value))/kbps"
            liveStreamer.audioBitrate = UInt32(slider.value * 1024)
        }
        if slider == videoBitrateSlider {
            videoBitrateLabel?.text = "video \(Int(slider.value))/kbps"
            liveStreamer.videoBitrate = UInt32(slider.value * 1024)
        }
        if slider == zoomSlider {
            liveStreamer.zoomRate = Float(slider.value)
        }
    }

    @IBAction func on(pause: UIButton) {
        
        liveStreamer.pauseStreaming()
    }

    @IBAction func on(close: UIButton) {
        
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func on(publish: UIButton) {
        
        if publish.isSelected {

            liveStreamer.stopStreaming()
            publish.setTitle("●", for: [])
            
        } else {
            
            let liveStreamUri: String = "rtmp://client33541:f32f1e8c@08fd49.entrypoint.cloud.wowza.com/app-399f"
            let liveStreamName: String = "c21b35ac"

            liveStreamer.startStreaming(uri: liveStreamUri, streamName:liveStreamName)
        }
        
        publish.isSelected = !publish.isSelected
    }
    
    @IBAction func on(record: UIButton) {
        
        if record.isSelected {
            
            UIApplication.shared.isIdleTimerDisabled = false

            liveStreamer.stopRecording()
            record.setTitle("●", for: [])
            
        } else {
            
            UIApplication.shared.isIdleTimerDisabled = true

            liveStreamer.startRecodring()
            record.setTitle("■", for: [])
        }
        
        record.isSelected = !record.isSelected
    }
 
    @IBAction func onFPSValueChanged(_ segment: UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            liveStreamer.videoFPS = 15.0
        case 1:
            liveStreamer.videoFPS = 30.0
        case 2:
            liveStreamer.videoFPS = 60.0
        default:
            break
        }
    }

    @IBAction func onEffectValueChanged(_ segment: UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            liveStreamer.removeCurrentEffector()
        case 1:
            liveStreamer.apply(effector: MonochromeEffect())
        case 2:
            liveStreamer.apply(effector: PronamaEffect())
        case 3:
            liveStreamer.apply(effector: CurrentTimeEffect())
        case 4:
            liveStreamer.apply(effector: BlurEffect())
        default:
            break
        }
    }
}
