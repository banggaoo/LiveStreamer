//
//  Running.swift
//  LiveStreamer
//
//  Created by James Lee on 24/04/2019.
//

import Foundation

protocol Running: class {
    var running: Bool { get }
    func startRunning()
    func stopRunning()
}
