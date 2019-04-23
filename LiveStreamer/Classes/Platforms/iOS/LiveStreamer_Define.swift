//
//  LiveStreamer_Define.swift
//  LiveStreamer
//
//  Created by st on 27/08/2018.
//

import Foundation
import AVFoundation

struct LiveStreamAddress {
    let uri: String
    let streamName: String
}

public struct Preference {
    
    static let defaultFPS: Float = 24.0
    
    static let videoDefaultBitrate: UInt32 = 1024 * 1024 * 1
    static let videoMinimumBitrate: UInt32 = 512 * 1024 * 1
    static let videoMaximumBitrate: UInt32 = 1024 * 1024 * 3
    
    static let audioDefaultBitrate: UInt32 = 192 * 1024
    static let audioMinimumBitrate: UInt32 = 96 * 1024
    static let audioMaximumBitrate: UInt32 = 192 * 1024
    
    static let sampleRate: Double = 44_100
    
    static let incrementBitrate: UInt32 = 512 * 1024
    
    static let videoSize: CGSize = CGSize(width: 1280, height: 720)
    static let sessionPreset: AVCaptureSession.Preset = .hd1280x720
    
    static let recordFileName = "Movie"
}

public enum BroadcastStatusForUser: String {
    
    case initialize = "LiveStreamer.Init"
    case ready = "LiveStreamer.Ready"
    case start = "LiveStreamer.Start"
    case startTrying = "LiveStreamer.Start.Trying"
    case startFailed = "LiveStreamer.Start.Failed"
    case failed = "LiveStreamer.Failed"
    case failedRetying = "LiveStreamer.Failed.Retrying"
    case failedTimeout = "LiveStreamer.Failed.Timeout"
    case pause = "LiveStreamer.Pause"
    case stop = "LiveStreamer.Stop"
    case terminated = "LiveStreamer.Terminated"
}
