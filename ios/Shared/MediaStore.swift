import Foundation
import os
import UIKit

enum MediaStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func url(for relativePath: String) -> URL? {
        AppGroup.containerURL?.appending(path: relativePath)
    }

    static func save(_ data: Data, named name: String) throws -> String {
        guard let container = AppGroup.containerURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = container.appending(path: "media", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        try data.write(to: folder.appending(path: safeName), options: .atomic)
        cache.removeObject(forKey: "media/\(safeName)" as NSString)
        return "media/\(safeName)"
    }

    static func image(at relativePath: String?) -> UIImage? {
        guard let relativePath else { return nil }
        if let cached = cache.object(forKey: relativePath as NSString) { return cached }
        guard let url = url(for: relativePath), let image = UIImage(contentsOfFile: url.path) else {
            Logger.store.error("no image at \(relativePath, privacy: .public)")
            return nil
        }
        cache.setObject(image, forKey: relativePath as NSString)
        return image
    }
}
