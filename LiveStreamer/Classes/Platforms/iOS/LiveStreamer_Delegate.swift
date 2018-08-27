//
//  LiveStreamer_Delegate.swift
//  LiveStreamer
//
//  Created by st on 27/08/2018.
//

import Foundation

class LiveStreamerRTMPStreamQoSDelegate: RTMPStreamDelegate {
    
    // detect upload insufficent BandWidth
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        
        if var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 {
            
            videoBitrate = UInt32(videoBitrate / 2)
            if videoBitrate < stream.minimumBitrate {
                videoBitrate = stream.minimumBitrate
            }
            
            stream.videoSettings["bitrate"] = videoBitrate
            
            //print("didPublishInsufficientBW \(videoBitrate)")
        }
    }
    
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        
        if var videoBitrate = stream.videoSettings["bitrate"] as? UInt32 {
            
            videoBitrate = videoBitrate + Preference.incrementBitrate
            if videoBitrate > stream.maximumBitrate {
                videoBitrate = stream.maximumBitrate
            }
            
            stream.videoSettings["bitrate"] = videoBitrate
            
            //print("didPublishSufficientBW \(videoBitrate)")
        }
    }
    
    func clear() {
        
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
