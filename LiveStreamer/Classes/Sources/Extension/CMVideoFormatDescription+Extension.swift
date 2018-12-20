import CoreMedia
import CoreImage

extension CMVideoFormatDescription {
    var dimensions: CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }

    static func create(pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        var formatDescription: CMFormatDescription?
        let status: OSStatus = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_422YpCbCr8,
            width: Int32(pixelBuffer.width),
            height: Int32(pixelBuffer.height),
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr else {
            //print("\(status)")
            return nil
        }
        return formatDescription
    }
}
