//
//  Log.swift
//  LiveStreamer
//
//  Created by James Lee on 22/04/2019.
//

import Foundation

func printLog(fileFullPath: String = #file, fc: String = #function, line: Int = #line, _ arg: Any?) {
    #if DEBUG
    let filename = fileFullPath.components(separatedBy: "/").last ?? "UnknownFile"
    print("[\(filename).\(fc):\(line) \(NSDate())]\n\(String(describing: arg))")
    #endif
}
