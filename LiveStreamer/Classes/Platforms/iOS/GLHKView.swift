import GLKit
import Foundation
import AVFoundation

public class GLHKView: GLKView {
    static let defaultOptions: [String: AnyObject] = [
        convertFromCIContextOption(CIContextOption.workingColorSpace): NSNull(),
        convertFromCIContextOption(CIContextOption.useSoftwareRenderer): NSNumber(value: false)
    ]
    public static var defaultBackgroundColor: UIColor = .black
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait

    private var displayImage: CIImage?
    private weak var currentStream: NetStream? {
        didSet { oldValue?.mixer.videoIO.drawable = nil }
    }
    
    public var streamLoaded: Bool {
        get { return (currentStream != nil) }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame, context: EAGLContext(api: .openGLES2)!)
        awakeFromNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        context = EAGLContext(api: .openGLES2)!
    }

    public override func awakeFromNib() {
        delegate = self
        enableSetNeedsDisplay = true
        backgroundColor = GLHKView.defaultBackgroundColor
        layer.backgroundColor = GLHKView.defaultBackgroundColor.cgColor
    }

    public func attachStream(_ stream: NetStream?) {
        runMixerIfCan(stream)
        currentStream = stream
    }
    private func runMixerIfCan(_ stream: NetStream?) {
        guard let stream = stream else { return }
        
        stream.mixer.videoIO.context = CIContext(eaglContext: context, options: convertToOptionalCIContextOptionDictionary(GLHKView.defaultOptions))
        stream.lockQueue.async {
            self.position = stream.mixer.videoIO.position
            stream.mixer.videoIO.drawable = self
            stream.mixer.startRunning()
        }
    }
}

extension GLHKView: GLKViewDelegate {

    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        guard let displayImage: CIImage = displayImage else { return }
        var inRect: CGRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect: CGRect = displayImage.extent
        VideoGravityUtil.calculate(videoGravity, inRect: &inRect, fromRect: &fromRect)
        currentStream?.mixer.videoIO.context?.draw(displayImage, in: inRect, from: fromRect)
        
        // If you want to reverse front facing camera image
//        currentStream?.mixer.videoIO.context?.draw(displayImage.oriented(forExifOrientation: 2), in: inRect, from: fromRect)
    }
}

extension GLHKView: NetStreamDrawable {

    func draw(image: CIImage) {
        DispatchQueue.main.async {
            self.displayImage = image
            self.setNeedsDisplay()
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCIContextOption(_ input: CIContextOption) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalCIContextOptionDictionary(_ input: [String: Any]?) -> [CIContextOption: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (CIContextOption(rawValue: key), value)})
}
