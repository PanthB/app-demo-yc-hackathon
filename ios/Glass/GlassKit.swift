import SwiftUI
import UIKit

enum GlassKit {
    static let paper = Color(red: 1.0, green: 0.984, blue: 0.949)
    static let ink = Color(red: 0.169, green: 0.141, blue: 0.125)
    static let tomato = Color(red: 1.0, green: 0.42, blue: 0.29)
    static let butter = Color(red: 1.0, green: 0.824, blue: 0.361)
    static let sky = Color(red: 0.486, green: 0.769, blue: 1.0)
    static let mint = Color(red: 0.561, green: 0.867, blue: 0.69)

    private static var known: [String: Bool] = [:]

    static func image(_ name: String) -> Image? {
        let full = "Kit/\(name)"
        let exists = known[full] ?? (UIImage(named: full) != nil)
        known[full] = exists
        return exists ? Image(full) : nil
    }
}

enum GlassMedia {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(at path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        if let hit = cache.object(forKey: path as NSString) { return hit }
        guard let root = AppGroup.containerURL,
              let image = UIImage(contentsOfFile: root.appending(path: path).path)
        else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
