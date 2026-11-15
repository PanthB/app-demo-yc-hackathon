import SwiftData
import SwiftUI

struct DropPipeline: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear(perform: wake)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { wake() }
            }
    }

    private func wake() {
        InboxIngest.appGroup?.run(in: context)
    }
}

extension View {
    func dropPipeline() -> some View {
        modifier(DropPipeline())
    }
}
