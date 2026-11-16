import SwiftUI

struct NightAddButton: View {
    @State private var showsCamera = false
    @Namespace private var camera

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 28) {
                Button {
                    showsCamera = true
                } label: {
                    Label("take a photo", systemImage: "camera")
                        .labelStyle(.iconOnly)
                }
                .controlSize(.large)
                .font(.title3.weight(NightStyle.symbolWeight))
                .accessibilityIdentifier("nightCamera")
                .matchedTransitionSource(id: "camera", in: camera)
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
                .navigationTransition(.zoom(sourceID: "camera", in: camera))
        }
    }
}
