import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (_ layerPoint: CGPoint, _ devicePoint: CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: (CGPoint, CGPoint) -> Void

        init(onTap: @escaping (CGPoint, CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func tapped(_ tap: UITapGestureRecognizer) {
            guard let view = tap.view as? PreviewView else { return }
            let point = tap.location(in: view)
            onTap(point, view.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
