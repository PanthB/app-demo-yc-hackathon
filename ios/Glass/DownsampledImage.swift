import ImageIO
import SwiftUI
import UIKit

struct DownsampledImage: View {
    private let source: Downsampler.Source?
    private let size: CGSize
    private let glyph: String
    private let fallback: UIImage?

    @Environment(\.displayScale) private var displayScale
    @State private var held: (key: String, image: UIImage)?
    @State private var failed: String?

    init(url: URL?, size: CGSize, glyph: String = "photo", fallback: UIImage? = nil) {
        source = url.map(Downsampler.Source.url)
        self.size = size
        self.glyph = glyph
        self.fallback = fallback
    }

    init(asset: String, size: CGSize, glyph: String = "photo") {
        source = .asset(asset)
        self.size = size
        self.glyph = glyph
        fallback = nil
    }

    var body: some View {
        let key = source.map { Downsampler.key($0, size: size, scale: displayScale) }
        let ready = key.flatMap { held?.key == $0 ? held?.image : Downsampler.cached($0) }
        let missing = key == nil || failed == key
        Color(.tertiarySystemFill)
            .overlay {
                if let ready {
                    Image(uiImage: ready).resizable().scaledToFill().transition(.opacity)
                } else if missing, let fallback {
                    Image(uiImage: fallback).resizable().scaledToFill()
                } else if missing {
                    Image(systemName: glyph)
                        .font((min(size.width, size.height) >= 56 ? Font.title2 : .caption).weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    SkeletonShimmer()
                }
            }
            .clipped()
            .task(id: key) {
                guard let source, let key else { return }
                if let hit = Downsampler.cached(key) {
                    if held?.key != key { held = (key, hit) }
                    return
                }
                let image = await Downsampler.load(source, size: size, scale: displayScale)
                guard !Task.isCancelled else { return }
                guard let image else {
                    failed = key
                    return
                }
                Downsampler.keep(image, for: key)
                withAnimation(.easeOut(duration: 0.2)) { held = (key, image) }
            }
    }
}

private struct SkeletonShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var across = false

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(colorScheme == .dark ? 0.07 : 0.45), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.7)
            .offset(x: across ? proxy.size.width : -proxy.size.width * 0.7)
        }
        .opacity(reduceMotion ? 0 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { across = true }
        }
        .accessibilityHidden(true)
    }
}

enum Downsampler {
    enum Source: Hashable, Sendable {
        case url(URL)
        case asset(String)
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    static func key(_ source: Source, size: CGSize, scale: CGFloat) -> String {
        let name: String
        switch source {
        case .url(let url): name = url.absoluteString
        case .asset(let asset): name = "asset:\(asset)"
        }
        return "\(name)|\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(Int(scale.rounded()))"
    }

    static func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func keep(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    static func load(_ source: Source, size: CGSize, scale: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            switch source {
            case .url(let url) where url.isFileURL:
                return thumbnail(CGImageSourceCreateWithURL(url as CFURL, nil), size: size, scale: scale)
            case .url(let url):
                var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if parts?.scheme == "http" { parts?.scheme = "https" }
                guard let secure = parts?.url, let (data, response) = try? await URLSession.shared.data(from: secure) else { return nil }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
                return thumbnail(CGImageSourceCreateWithData(data as CFData, nil), size: size, scale: scale)
            case .asset(let name):
                guard let image = UIImage(named: name), image.size.width > 0, image.size.height > 0 else { return nil }
                let fill = max(size.width / image.size.width, size.height / image.size.height)
                let fitted = CGSize(width: image.size.width * min(fill, 1), height: image.size.height * min(fill, 1))
                return image.preparingThumbnail(of: fitted)
            }
        }.value
    }

    private static func thumbnail(_ source: CGImageSource?, size: CGSize, scale: CGFloat) -> UIImage? {
        guard let source else { return nil }
        var longest = Double(max(size.width, size.height) * scale)
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Double,
           let height = properties[kCGImagePropertyPixelHeight] as? Double,
           min(width, height) > 0 {
            longest = min(max(width, height), max(width, height) * longest / min(width, height))
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(longest.rounded(.up), 1),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
