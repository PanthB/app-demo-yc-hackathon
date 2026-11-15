import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFiles {
    static func downsampled(_ url: URL, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { downsampled($0, maxPixel: maxPixel) }
    }

    static func downsampled(_ data: Data, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { downsampled($0, maxPixel: maxPixel) }
    }

    private static func downsampled(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func writeJPEG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }
}
