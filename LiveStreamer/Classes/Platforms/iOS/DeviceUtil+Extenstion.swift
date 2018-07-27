import Foundation
import AVFoundation

extension DeviceUtil {
    static public func videoOrientation(by notification: Notification) -> AVCaptureVideoOrientation? {
        guard let device: UIDevice = notification.object as? UIDevice else {
            return nil
        }
        return videoOrientation(by: device.orientation)
    }

    static public func videoOrientation(by orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }
}

extension AVCaptureDevice {

    func supportedPreset(_ preset: AVCaptureSession.Preset) -> AVCaptureSession.Preset {
        
        if self.supportsSessionPreset(preset) { return preset }
        
        let formatDescription: CMFormatDescription = activeFormat.formatDescription
        let dimension: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        
        var supportedPreset: AVCaptureSession.Preset = .low
        
        switch dimension.height {
            
        case 2160..<3839:
            supportedPreset = .hd4K3840x2160
            
        case 1080..<2159:
            supportedPreset = .hd1920x1080
            
        case 720..<1079:
            supportedPreset = .hd1280x720
            
        case 540..<719:
            supportedPreset = .iFrame960x540
            
        default:
            supportedPreset = .low
        }
        
        return supportedPreset
    }
}
