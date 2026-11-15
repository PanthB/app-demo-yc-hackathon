import SwiftUI

struct NightAddButton: View {
    @State private var showsCamera = false

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    showsCamera = true
                } label: {
                    Label("take a photo", systemImage: "camera")
                        .labelStyle(.iconOnly)
                }
                .controlSize(.large)
                .font(.title3.weight(NightStyle.symbolWeight))
                .accessibilityIdentifier("nightCamera")
                AddMenu()
                    .menuStyle(.button)
                    .controlSize(.extraLarge)
                    .font(.title.weight(NightStyle.symbolWeight))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(.white)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .fullScreenCover(isPresented: $showsCamera) {
            DropCamera()
        }
    }
}
