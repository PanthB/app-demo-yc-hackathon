import Foundation
import PDFKit
import UIKit

enum PDFReading {
    struct Read {
        var text: String?
        var firstPage: CGImage?
    }

    static func read(_ url: URL) -> Read {
        guard let document = PDFDocument(url: url) else { return Read() }
        let text = (0..<min(document.pageCount, 5))
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Read(
            text: text.isEmpty ? nil : text,
            firstPage: document.page(at: 0)?.thumbnail(of: CGSize(width: 1600, height: 1600), for: .mediaBox).cgImage
        )
    }
}
