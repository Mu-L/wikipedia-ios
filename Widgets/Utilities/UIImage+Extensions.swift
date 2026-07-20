import UIKit
import ImageIO

extension UIImage {
    /// Widget extensions have a ~30MB memory ceiling, so full-size UIImage(data:)
    /// decodes + renderer-based rescaling can get the process jetsammed. This decodes
    /// directly at the target size via ImageIO, never materializing the full bitmap.
    static func downsampled(from data: Data, targetSize: CGSize) -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height)
        ] as CFDictionary
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
