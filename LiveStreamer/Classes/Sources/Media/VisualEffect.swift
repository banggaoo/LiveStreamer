import AVFoundation
import CoreImage
import Foundation

open class VisualEffect: NSObject {
    open var ciContext: CIContext?

    open func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        return image
    }
}
