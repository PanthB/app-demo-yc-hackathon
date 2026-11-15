import ImageIO
import os
import SwiftUI
import UIKit

final class NightPicture: @unchecked Sendable {
    let key: String
    let image: CGImage
    let tone: Color

    init(key: String, image: CGImage, tone: Color) {
        self.key = key
        self.image = image
        self.tone = tone
    }
}

enum NightImage {
    private static let cache = NSCache<NSString, NightPicture>()

    static func cacheKey(_ path: String, pixels: Int) -> String {
        "\(path)@\(pixels)"
    }

    static func cached(_ key: String) -> NightPicture? {
        cache.object(forKey: key as NSString)
    }

    static func load(_ path: String, toneKey: String, pixels: Int) async -> NightPicture? {
        let key = cacheKey(path, pixels: pixels)
        if let picture = cached(key) { return picture }
        guard let url = MediaStore.url(for: path) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            NightImage.decode(url, key: key, toneKey: toneKey, pixels: pixels)
        }.value
    }

    private static func decode(_ url: URL, key: String, toneKey: String, pixels: Int) -> NightPicture? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            Logger.store.error("no thumbnail for \(key, privacy: .public)")
            return nil
        }
        let picture = NightPicture(key: key, image: image, tone: ArtworkTone.color(of: UIImage(cgImage: image), key: toneKey))
        NightImage.cache.setObject(picture, forKey: key as NSString)
        return picture
    }
}

struct NightSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.white.opacity(0.04)
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                Color.white.opacity(0.04)
                    .overlay {
                        LinearGradient(colors: [.clear, .white.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
                            .visualEffect { content, proxy in
                                content.offset(x: (phase * 2 - 1) * proxy.size.width)
                            }
                    }
                    .clipped()
            }
        }
    }
}
