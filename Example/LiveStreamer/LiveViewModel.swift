//
//  LiveViewModel.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

final class LiveViewModel {
    var isStreamingStart = false
    
    let uri: String
    let streamName: String

    init(with uri: String, _ streamName: String) {
        self.uri = uri
        self.streamName = streamName
    }
}
