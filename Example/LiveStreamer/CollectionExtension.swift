//
//  CollectionExtension.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

extension Collection {
    
    func reverseOverflow(_ index: Int) -> Int {
        if self.count <= index {
            return 0
        }
        if 0 > index {
            return self.count - 1
        }
        return index
    }
    
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
