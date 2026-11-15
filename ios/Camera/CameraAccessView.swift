import PhotosUI
import SwiftUI
import UIKit

struct CameraAccessView: View {
    let access: CameraAccess
    let boardName: String
    let onAsk: () -> Void
    let onPicked: ([PhotosPickerItem]) -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .glassEffect(.regular, in: .circle)
                .padding(.bottom, 28)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .padding(.bottom, 12)
            Text(words)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            VStack(spacing: 12) {
                primary
                    .tint(.white)
                    .foregroundStyle(.black)
                secondary
                    .foregroundStyle(.white)
            }
            .font(.body.weight(.semibold))
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            onPicked(items)
        }
    }

    private var symbol: String {
        switch access {
        case .notAsked, .checking, .allowed: "camera.aperture"
        case .denied: "camera"
        case .unavailable: "photo.on.rectangle.angled"
        }
    }

    private var title: String {
        switch access {
        case .notAsked, .checking, .allowed: "let's take a photo for \(boardName)."
        case .denied: "your camera is off for this app."
        case .unavailable: "there's no camera i can use here."
        }
    }

    private var words: String {
        switch access {
        case .notAsked, .checking, .allowed:
            "i'll need your camera for that. each photo goes straight onto the board, and nowhere else."
        case .denied:
            "you can turn it back on in settings, then come right back and take the photo."
        case .unavailable:
            "you can still add a photo you already have, and it'll land in \(boardName)."
        }
    }

    @ViewBuilder
    private var primary: some View {
        switch access {
        case .notAsked, .checking, .allowed:
            Button(action: onAsk) {
                Text("turn on the camera").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("cameraAsk")
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("open settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("cameraSettings")
        case .unavailable:
            picker("pick from your photos")
                .buttonStyle(.glassProminent)
        }
    }

    @ViewBuilder
    private var secondary: some View {
        switch access {
        case .denied:
            picker("pick one from your photos instead")
                .buttonStyle(.glass)
        default:
            Button(action: onClose) {
                Text("not now").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private func picker(_ words: String) -> some View {
        PhotosPicker(selection: $picked, maxSelectionCount: 4, matching: .images) {
            Text(words).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("cameraPickInstead")
    }
}

struct CameraBackdrop: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.62, 0.42], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                .black, Color(red: 0.05, green: 0.06, blue: 0.2), .black,
                Color(red: 0.1, green: 0.16, blue: 0.55), Color(red: 0.98, green: 0.45, blue: 0.2), Color(red: 0.05, green: 0.35, blue: 0.4),
                .black, Color(red: 0.06, green: 0.05, blue: 0.14), .black,
            ]
        )
        .overlay { Grain().blendMode(.overlay) }
        .ignoresSafeArea()
    }
}

private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x2545_F491_4F6C_DD1D
            func next() -> CGFloat {
                seed ^= seed << 13
                seed ^= seed >> 7
                seed ^= seed << 17
                return CGFloat(seed % 10_000) / 10_000
            }
            let count = Int(size.width * size.height / 18)
            for _ in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(Double(next()) * 0.5)))
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}
