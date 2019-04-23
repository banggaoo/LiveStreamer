//
//  ViewController.swift
//  LiveStreamer_Example
//
//  Created by James Lee on 22/04/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit

final class ViewController: UIViewController {
    @IBOutlet private weak var streamNameTextField: UITextField!
    @IBOutlet private weak var uriTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        getStreamInfoFromUserDefault()
    }
    
    @IBAction private func didTapEnterButton(_ sender: Any) {
        guard let streamName = streamNameTextField.text, streamName.count > 0 else { return }
        guard let uri = uriTextField.text, uri.count > 0 else { return }
        storeStreamInfoToUserDefault(with: uri, streamName)
        
        let vc = LiveViewController(with: uri, streamName)
        present(vc, animated: true, completion: nil)
    }
    
    static private let StreamInfoKey = "STREAM_INFO_DIC"
    
    private func storeStreamInfoToUserDefault(with uri: String, _ streamName: String) {
        let streamInfo = StreamInfoModel(uri: uri, streamName: streamName)
        
        let dataEncode = try? JSONEncoder().encode(streamInfo)
        UserDefaults.standard.set(dataEncode, forKey: ViewController.StreamInfoKey)
        UserDefaults.standard.synchronize()
    }

    private func getStreamInfoFromUserDefault() {
        guard let dateEncode = UserDefaults.standard.object(forKey: ViewController.StreamInfoKey) else { return }
        guard let streamInfo = try? JSONDecoder().decode(StreamInfoModel.self, from: dateEncode as! Data) else { return }
        
        streamNameTextField.text = streamInfo.streamName
        uriTextField.text = streamInfo.uri
    }
}
