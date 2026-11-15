import SwiftUI

struct DropThumbnail: View {
    let face: PreviewFace
    let kind: DropKind
    var side: CGFloat = 56
    var radius: CGFloat = 12

    var body: some View {
        Color(.tertiarySystemFill)
            .frame(width: side, height: side)
            .overlay {
                switch face {
                case .image(let image):
                    Image(uiImage: image).resizable().scaledToFill()
                case .cutout(let image):
                    Image(uiImage: image).resizable().scaledToFit().padding(4)
                case .words, .date, .countdown, .waveform, .plain:
                    Image(systemName: kind.symbol).font(.title3.weight(.semibold)).foregroundStyle(.tint)
                }
            }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
