//
//  LiveStreamer_Delegate.swift
//  LiveStreamer
//
//  Created by st on 27/08/2018.
//

import Foundation

class LiveStreamerRTMPStreamQoSDelegate: RTMPStreamDelegate {
    
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 else { return }
        printLog("didPublishInsufficientBW \(videoBitrate)")

        videoBitrate = UInt32(videoBitrate / 2)
        if videoBitrate < stream.minimumBitrate {
            videoBitrate = stream.minimumBitrate
        }
        stream.videoSettings["bitrate"] = videoBitrate
    }
    
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 else { return }
        printLog("didPublishSufficientBW \(videoBitrate)")

        videoBitrate = videoBitrate + Preference.incrementBitrate
        if videoBitrate > stream.maximumBitrate {
            videoBitrate = stream.maximumBitrate
        }
        stream.videoSettings["bitrate"] = videoBitrate
    }
    
    func clear(_ stream: RTMPStream) {
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
