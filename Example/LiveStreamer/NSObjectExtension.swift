//
//  NSObjectExtension.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

protocol ClassNameable {
    static var className: String { get }
}

extension ClassNameable {
    static var className: String {
        return String(describing: self)
    }
}

extension NSObject: ClassNameable {}
