import CoreImage
import Foundation
import Vision

enum ImageReading {
    enum Cutout: Equatable, Sendable {
        case saved
        case noSubject
        case unavailable(String)
    }

    static func liftSubject(from image: CGImage, to url: URL) -> Cutout {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return .noSubject }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let lifted = CIImage(cvPixelBuffer: buffer)
            let share = (lifted.extent.width * lifted.extent.height) / CGFloat(image.width * image.height)
            guard share >= 0.03, share <= 0.85, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return .noSubject }
            try CIContext().writePNGRepresentation(of: lifted, to: url, format: .RGBA8, colorSpace: colorSpace)
            return .saved
        } catch {
            return .unavailable(String(describing: error))
        }
    }
}
