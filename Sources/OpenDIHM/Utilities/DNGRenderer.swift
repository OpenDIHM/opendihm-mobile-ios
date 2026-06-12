import CoreImage
import Foundation
import UIKit

enum DNGRenderer {
    static func thumbnail(at url: URL, maxPixelSize: Int = 512) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    static func fullImage(at url: URL) -> UIImage? {
        let filter = CIRAWFilter(imageURL: url)
        guard let outputImage = filter?.outputImage else {
            return thumbnail(at: url, maxPixelSize: 2048)
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
