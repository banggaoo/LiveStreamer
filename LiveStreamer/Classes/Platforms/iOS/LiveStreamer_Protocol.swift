//
//  LiveStreamer_Protocol.swift
//  LiveStreamer
//
//  Created by James Lee on 23/04/2019.
//

import Foundation
import AVFoundation

public protocol LiveStreamingDelegate: class {
    func broadcastStatusForUserWith(code: String)
    func broadcastStatusWith(code: String)
    func fpsChanged(fps: Float)
}

public protocol LiveRecorderDelegate: class {
    func didFinishWriting(_ recorder: AVMixerRecorder)
    func didStartRunning(_ recorder: AVMixerRecorder)
}

public protocol LiveStreamerControlInterface: class {
    var delegate: LiveStreamingDelegate? { get set }
    var recorderDelegate: LiveRecorderDelegate? { get set }
    
    init(with view: GLHKView)
    func startCapturingIfCan() -> Bool
    
    func startStreamingIfCan(with uri: String, _ streamName: String) -> Bool
    func stopStreamingIfCan() -> Bool
    func pauseStreaming()
    
    func startRecordingIfCan()
    func stopRecordingIfCan()
    
    func applyEffectorIfCan(_ effector: VisualEffect) -> Bool
    func removeCurrentEffectorIfCan() -> Bool
}

public protocol LiveStreamerConfigureInterface: class {
    var cameraPosition: AVCaptureDevice.Position { get set }
    var abrOn: Bool { get set }
    var audioMuted: Bool { get set }
    var videoBitrate: UInt32 { get set }
    var audioBitrate: UInt32 { get set }
    var maximumVideoBitrate: UInt32 { get set }
    var minimumVideoBitrate: UInt32 { get set }
    var zoomRate: Float { get set }
    var torch: Bool { get set }
    var torchModeSupported: Bool { get }
    var sampleRate: Double { get set }
    var sessionPreset: AVCaptureSession.Preset { get set }
    var videoSize: CGSize { get set }
    var videoFPS: Float { get set }
    var recordFileName: String { get set }
    var syncOrientation: Bool { get set }
}

public protocol LiveStreamerRetryProtocol: class {
    var broadcastTimeout: TimeInterval { get set }
    var retryConnectInterval: TimeInterval { get set }
    var unableTimeCount: TimeInterval { get set }
}
