import LiveStreamer
import UIKit
import AVFoundation

final class CurrentTimeEffect: VisualEffect {
    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")

    let label: UILabel = {
        let label: UILabel = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        return label
    }()

    override func execute(_ image: CIImage) -> CIImage {
        let now: Date = Date()
        let nowDescription: String = now.description

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 25)
        ]

        UIGraphicsBeginImageContext(image.extent.size)
        nowDescription.draw(at: CGPoint(x: 20, y: 70), withAttributes: textAttributes)
        let result: CIImage = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)!
        UIGraphicsEndImageContext()

        filter!.setValue(result, forKey: "inputImage")
        filter!.setValue(image, forKey: "inputBackgroundImage")

        return filter!.outputImage!
    }
}

final class PronamaEffect: VisualEffect {
    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")

    var extent: CGRect = CGRect.zero {
        didSet {
            if extent == oldValue { return }
            UIGraphicsBeginImageContext(extent.size)
            let image: UIImage = UIImage(named: "Logo.png")!
            image.draw(at: CGPoint(x: 50, y: 60))
            pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    var pronama: CIImage?

    override init() {
        super.init()
    }

    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else { return image }
        extent = image.extent
        filter.setValue(pronama!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}

final class MonochromeEffect: VisualEffect {
    let filter: CIFilter? = CIFilter(name: "CIColorMonochrome")
    
    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else { return image }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}

final class BlurEffect: VisualEffect {
    let filter: CIFilter? = CIFilter(name: "CIGaussianBlur")
    
    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else { return image }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(1.0, forKey: "inputRadius")
        //filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}
