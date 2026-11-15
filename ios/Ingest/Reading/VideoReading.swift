import AVFoundation
import Foundation
import os

enum VideoReading {
    static func frames(of url: URL, into folder: URL) async -> [URL] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1600, height: 1600)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let seconds = try await asset.load(.duration).seconds
            guard seconds.isFinite, seconds > 0 else { return [] }
            var saved: [URL] = []
            for (index, fraction) in [0.1, 0.35, 0.6, 0.85].enumerated() {
                let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
                do {
                    let frame = try await generator.image(at: time).image
                    let destination = folder.appending(path: "frame-\(index).jpg")
                    if ImageFiles.writeJPEG(frame, to: destination) { saved.append(destination) }
                } catch {
                    Logger.ingest.error("no frame at \(Int(fraction * 100))% of \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
            return saved
        } catch {
            Logger.ingest.error("couldn't open \(url.lastPathComponent, privacy: .public) as a video: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
