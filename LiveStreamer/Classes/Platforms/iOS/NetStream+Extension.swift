import Foundation
import AVFoundation

extension NetStream {
    public var orientation: AVCaptureVideoOrientation {
        get { return mixer.videoIO.orientation }
        set (newValue) { self.mixer.videoIO.orientation = newValue }
    }

    public func attachScreen(_ screen: ScreenCaptureSession?, useScreenSize: Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }

    public var zoomFactor: CGFloat {
        return self.mixer.videoIO.zoomFactor
    }

    public func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool = false, withRate: Float = 2.0) {
        self.mixer.videoIO.setZoomFactor(zoomFactor, ramping: ramping, withRate: withRate)
    }
}
