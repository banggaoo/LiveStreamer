//
//  LiveStreamer_Define.swift
//  LiveStreamer
//
//  Created by st on 27/08/2018.
//

import Foundation

struct LiveStreamAddress {
    // If you want to use singleton
    //static var defaultInstance: Preference = Preference()
    
    // uri is like "rtmp://test:test@192.168.11.15/live",  "rtmp://1b6cf5.entrypoint.cloud.wowza.com/app-6f91"
    public var uri: String
    public var streamName: String  // ex : "188e39fc"
}

public struct Preference {
    
    static public let defaultFPS: Float = 24.0
    
    static public let defaultBitrate: UInt32 = 1024 * 1024 * 1
    static public let minimumBitrate: UInt32 = 512 * 1024 * 1
    static public let maximumBitrate: UInt32 = 1024 * 1024 * 3
    
    static public let audioDefaultBitrate: UInt32 = 192 * 1024
    static public let audioMinimumBitrate: UInt32 = 96 * 1024
    static public let audioMaximumBitrate: UInt32 = 192 * 1024
    
    static public let sampleRate: Double = 44_100
    
    static public let incrementBitrate: UInt32 = 512 * 1024
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
