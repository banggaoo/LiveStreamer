//
//  LiveViewController_Recorder.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import LiveStreamer
import AVFoundation
import Photos

extension LiveViewController: LiveRecorderDelegate {
    
    public func didFinishWriting(_ recorder: AVMixerRecorder) {
        guard let writer: AVAssetWriter = recorder.writer else { return }
        
        PHPhotoLibrary.shared().performChanges({() in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { (_, error) in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                printLog(error)
            }
        })
    }
    
    public func didStartRunning(_ recorder: AVMixerRecorder) {
    }
}
