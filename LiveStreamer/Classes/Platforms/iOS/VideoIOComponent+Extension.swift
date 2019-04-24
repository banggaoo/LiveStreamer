import CoreMedia
import Foundation
import AVFoundation

extension VideoIOComponent {
    var zoomFactor: CGFloat {
        guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device else { return 0 }
        return device.videoZoomFactor
    }

    func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool, withRate: Float) {
        guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
            1 <= zoomFactor && zoomFactor < device.activeFormat.videoMaxZoomFactor
            else { return }
        do {
            try device.lockForConfiguration()
            if ramping {
                device.ramp(toVideoZoomFactor: zoomFactor, withRate: withRate)
            } else {
                device.videoZoomFactor = zoomFactor
            }
            device.unlockForConfiguration()
        } catch let error {
            printLog("while locking device for ramp: \(error)")
        }
    }

    func attachScreen(_ screen: ScreenCaptureSession?, useScreenSize: Bool = true) {
        guard let screen: ScreenCaptureSession = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        input = nil
        output = nil
        if useScreenSize == true {
            encoder.setValuesForKeys([
                "width": screen.attributes["Width"]!,
                "height": screen.attributes["Height"]!
            ])
        }
        self.screen = screen
    }
}

extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {

    func didSet(size: CGSize) {
        lockQueue.async {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func output(pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        if effects.isEmpty == false {
            context?.render(effect(pixelBuffer), to: pixelBuffer)
        }
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: withPresentationTime,
            duration: CMTime.invalid
        )
        mixer?.recorder.appendPixelBuffer(pixelBuffer, withPresentationTime: withPresentationTime)
    }
}
