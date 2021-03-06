import UIKit
import AVFoundation
import LiveStreamer

final class LiveViewController: UIViewController {
    private let viewModel: LiveViewModel
    
    // MARK: Interface
    
    init(with uri: String, _ streamName: String) {
        viewModel = LiveViewModel(with: uri, streamName)
        
        super.init(nibName: LiveViewController.className, bundle: nil)
    }
    
    // MARK: Lifecycle
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        printLog("viewDidAppear")

        // It is better to run startCapturing method after view is appeared
        liveStreamer.cameraPosition = .front
        _ = liveStreamer.startCapturingIfCan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopStreaming()
        stopRecording()
    }
    
    public override var shouldAutorotate: Bool {
        get { return (viewModel.isStreamingStart == false) }
    }
    
    deinit {
        printLog("deinit")
    }
    
    // MARK: Preview
    
    static private let sessionPreset = AVCaptureSession.Preset.hd1280x720
    static private let videoSize = CGSize(width: 720, height: 1280)
    
    @IBOutlet private weak var lfView: GLHKView!
    
    lazy private var liveStreamer: LiveStreamer = {
        let streamer = LiveStreamer(with: lfView)
        streamer.delegate = self
        streamer.recorderDelegate = self
        
        // Please be sure your device`s camera support resolution with front/back camera both. If you set higher resolution, camera doesn't work properly
        streamer.sessionPreset = LiveViewController.sessionPreset
        streamer.videoSize = LiveViewController.videoSize
        return streamer
    }()
    
    // MARK: Control
    
    private func startStreaming() {
        guard liveStreamer.startStreamingIfCan(with: viewModel.uri, viewModel.streamName) == true else { return }
        viewModel.isStreamingStart = true
    }
    private func stopStreaming() {
        guard liveStreamer.stopStreamingIfCan() == true else { return }
        viewModel.isStreamingStart = false
    }
    private func pauseStreaming() {
        liveStreamer.pauseStreaming()
        pauseButton.isSelected = (pauseButton.isSelected == false)
    }
    
    private func startRecoding() {
        UIApplication.shared.isIdleTimerDisabled = true
        liveStreamer.startRecordingIfCan()
    }
    private func stopRecording() {
        UIApplication.shared.isIdleTimerDisabled = false
        liveStreamer.stopRecordingIfCan()
    }
 
    // MARK: UI
    
    @IBOutlet private weak var currentFPSLabel: UILabel!
    @IBOutlet private weak var torchButton: UIButton!
    @IBOutlet private weak var fpsControl: UISegmentedControl!
    @IBOutlet private weak var effectSegmentControl: UISegmentedControl!
    
    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var videoMuteButton: UIButton!
    @IBOutlet private weak var audioMuteButton: UIButton!
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var publishButton: UIButton!
    @IBOutlet private weak var pauseButton: UIButton!
    
    @IBOutlet private weak var zoomSlider: UISlider!
    @IBOutlet private weak var videoBitrateLabel: UILabel!
    @IBOutlet private weak var videoBitrateSlider: UISlider!
    @IBOutlet private weak var audioBitrateLabel: UILabel!
    @IBOutlet private weak var audioBitrateSlider: UISlider!

    @IBAction func didTapCloseButton(_ sender: Any) {
        close()
    }
    private func close() { 
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func rotateCamera(_ sender: UIButton) {
        let position: AVCaptureDevice.Position = (liveStreamer.cameraPosition == .back) ? .front : .back
        setCameraPosition(position)
    }
    private func setCameraPosition(_ position: AVCaptureDevice.Position) {
        liveStreamer.cameraPosition = position
        torchButton.isEnabled = (position == .back)
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
 
    @IBAction private func on(mute: UIButton) {
        if mute == videoMuteButton {
            liveStreamer.videoMuted = (liveStreamer.videoMuted == false)
            mute.isSelected = liveStreamer.videoMuted
        } else if mute == audioMuteButton {
            liveStreamer.audioMuted = (liveStreamer.audioMuted == false)
            mute.isSelected = liveStreamer.audioMuted
        }
    }
    @IBAction private func on(pause: UIButton) {
        pauseStreaming()
    }
    @IBAction private func on(publish: UIButton) {
        (publish.isSelected == true) ? stopStreaming() : startStreaming()
        publish.isSelected = (publish.isSelected == false)
    }
    @IBAction private func on(record: UIButton) {
        (record.isSelected == true) ? stopRecording() : startRecoding()
        record.isSelected = (record.isSelected == false)
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
            _ = liveStreamer.removeCurrentEffectorIfCan()
        case .mono:
            _ = liveStreamer.applyEffectorIfCan(MonochromeEffect())
        case .pronama:
            _ = liveStreamer.applyEffectorIfCan(PronamaEffect())
        case .time:
            _ = liveStreamer.applyEffectorIfCan(CurrentTimeEffect())
        case .blur:
            _ = liveStreamer.applyEffectorIfCan(BlurEffect())
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
