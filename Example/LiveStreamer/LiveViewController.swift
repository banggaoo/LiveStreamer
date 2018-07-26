import LiveStreamer
import UIKit
import AVFoundation


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
            }
            break
        }
    }
    
    func fpsChanged(fps: Float) {
        
        
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
        
        liveStreamer.videoSize = CGSize(width: 1920, height: 1080)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "currentFPS" {
            
            if Thread.isMainThread {
                
                currentFPSLabel?.text = "FPS : \(object ?? "")"
            }
        }
    }
 
    @IBAction func rotateCamera(_ sender: UIButton) {
 
        let position: AVCaptureDevice.Position = liveStreamer.cameraPosition == .back ? .front : .back
        liveStreamer.cameraPosition = position
    }

    @IBAction func toggleTorch(_ sender: UIButton) {
        
        if let liveStreamer: LiveStreamer = liveStreamer {
            
            liveStreamer.torch = !(liveStreamer.torch)
        }
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
