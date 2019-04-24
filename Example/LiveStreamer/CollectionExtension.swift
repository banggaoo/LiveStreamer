//
//  CollectionExtension.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

extension Collection {    
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
