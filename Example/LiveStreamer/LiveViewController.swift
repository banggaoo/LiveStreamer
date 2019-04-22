import UIKit
import AVFoundation
import LiveStreamer

final class LiveViewController: UIViewController {
    private let viewModel: LiveViewModel
    
    @IBOutlet private weak var lfView: GLHKView!

    lazy private var liveStreamer: LiveStreamer = {
        let streamer = LiveStreamer(view: lfView)
        streamer.delegate = self
        streamer.recorderDelegate = self
        
        // Please be sure your device`s camera support resolution with front/back camera both. If you set higher resolution, camera doesn't work properly
        streamer.sessionPreset = AVCaptureSession.Preset.hd1280x720
        streamer.videoSize = CGSize(width: 720, height: 1280)
        return streamer
    }()
    
    init(with uri: String, _ streamName: String) {
        viewModel = LiveViewModel(with: uri, streamName)
        
        super.init(nibName: LiveViewController.className, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // It is better to run startCapturing method after view is appeared
        liveStreamer.startCapturing()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        liveStreamer.stopStreaming()
        liveStreamer.stopRecording()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    public override var shouldAutorotate: Bool {
        get { return (viewModel.isStreamingStart == false) }
    }
    
    @IBOutlet private weak var currentFPSLabel: UILabel!
    @IBOutlet private weak var fpsControl: UISegmentedControl!
    @IBOutlet private weak var effectSegmentControl: UISegmentedControl!
    
    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var publishButton: UIButton!
    @IBOutlet private weak var pauseButton: UIButton!
    
    @IBOutlet private weak var zoomSlider: UISlider!
    @IBOutlet private weak var videoBitrateLabel: UILabel!
    @IBOutlet private weak var videoBitrateSlider: UISlider!
    @IBOutlet private weak var audioBitrateLabel: UILabel!
    @IBOutlet private weak var audioBitrateSlider: UISlider!

    @IBAction private func rotateCamera(_ sender: UIButton) {
        let position: AVCaptureDevice.Position = liveStreamer.cameraPosition == .back ? .front : .back
        liveStreamer.cameraPosition = position
    }

    @IBAction private func toggleTorch(_ sender: UIButton) {
        liveStreamer.torch = (liveStreamer.torch == false)
    }

    @IBAction private func on(slider: UISlider) {
        updateAudioBitrateIfCan(with: slider)
        updateVideoBitrateIfCan(with: slider)
        updateZoomRateIfCan(with: slider)
    }
    private func updateAudioBitrateIfCan(with slider: UISlider) {
        guard slider == audioBitrateSlider else { return }
        audioBitrateLabel?.text = "audio \(Int(slider.value))/kbps"
        liveStreamer.audioBitrate = UInt32(slider.value * 1024)
    }
    private func updateVideoBitrateIfCan(with slider: UISlider) {
        guard slider == videoBitrateSlider else { return }
        videoBitrateLabel?.text = "video \(Int(slider.value))/kbps"
        liveStreamer.videoBitrate = UInt32(slider.value * 1024)
    }
    private func updateZoomRateIfCan(with slider: UISlider) {
        guard slider == zoomSlider else { return }
        liveStreamer.zoomRate = Float(slider.value)
    }

    private func pauseStream() {
        liveStreamer.audioMuted = !(liveStreamer.audioMuted)
    }
    
    @IBAction private func on(pause: UIButton) {
        pauseStream()
    }

    @IBAction private func on(close: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func on(publish: UIButton) {

        if publish.isSelected {
            liveStreamer.stopStreaming()
            viewModel.isStreamingStart = false
            
        } else {
            let liveStreamUri = Preference.Stream.uri
            let liveStreamName = Preference.Stream.streamName
            
            liveStreamer.startStreaming(uri: liveStreamUri, streamName:liveStreamName)
            
            viewModel.isStreamingStart = true
        }
        publish.isSelected = (publish.isSelected == false)
    }
    
    @IBAction private func on(record: UIButton) {
        
        if record.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false

            liveStreamer.stopRecording()
            record.isSelected = false
            
        } else {
            UIApplication.shared.isIdleTimerDisabled = true

            liveStreamer.startRecodring()
            record.isSelected = true
        }
        record.isSelected = !record.isSelected
    }
 
    enum FPS: Float, CaseIterable {
        case low = 15.0
        case medium = 30.0
        case high = 60.0
    }
    
    @IBAction private func onFPSValueChanged(_ segment: UISegmentedControl) {
        guard let fpsCase = FPS.allCases[safe: segment.selectedSegmentIndex] else { return }
        liveStreamer.videoFPS = fpsCase.rawValue
    }
    
    enum Effect: CaseIterable {
        case none, mono, pronama, time, blur
    }

    @IBAction private func onEffectValueChanged(_ segment: UISegmentedControl) {
        guard let effectType = Effect.allCases[safe: segment.selectedSegmentIndex] else { return }

        switch effectType {
        case .none:
            liveStreamer.removeCurrentEffector()
        case .mono:
            liveStreamer.apply(effector: MonochromeEffect())
        case .pronama:
            liveStreamer.apply(effector: PronamaEffect())
        case .time:
            liveStreamer.apply(effector: CurrentTimeEffect())
        case .blur:
            liveStreamer.apply(effector: BlurEffect())
        }
    }
}

extension LiveViewController: LiveStreamingDelegate {
    
    func broadcastStatusForUserWith(code: String) {
        
        switch code {
            
        case BroadcastStatusForUser.start.rawValue:
            DispatchQueue.main.async {
                self.publishButton?.isSelected = true
                UIApplication.shared.isIdleTimerDisabled = true
            }
            
        case BroadcastStatusForUser.stop.rawValue:
            DispatchQueue.main.async {
                self.publishButton?.isSelected = false
                UIApplication.shared.isIdleTimerDisabled = false
                self.publishButton?.isSelected = !((self.publishButton?.isSelected)!)
            }
            
        default:
            break
        }
    }
    
    func broadcastStatusWith(code: String) {
        DispatchQueue.main.async {
            self.stateLabel.text = code
        }
        
        switch code {
            
        case RTMPConnection.Code.connectSuccess.rawValue,
             RTMPStream.Code.publishStart.rawValue,
             RTMPStream.Code.connectSuccess.rawValue:
            break
            
        case RTMPConnection.Code.connectNetworkChange.rawValue:
            break
            
        case RTMPConnection.Code.connectClosed.rawValue,
             RTMPConnection.Code.connectFailed.rawValue,
             RTMPConnection.Code.connectIdleTimeOut.rawValue,
             RTMPConnection.Code.connectInvalidApp.rawValue,
             RTMPStream.Code.connectRejected.rawValue,
             RTMPStream.Code.connectFailed.rawValue,
             RTMPStream.Code.connectClosed.rawValue:
            break
            
        default:
            break
        }
    }
    
    func fpsChanged(fps: Float) {
        DispatchQueue.main.async {
            self.currentFPSLabel?.text = "FPS : \(fps)"
        }
    }
}
