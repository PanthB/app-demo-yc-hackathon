import SwiftUI

struct GlassBoardRoot: View {
    var body: some View {
        #if DEBUG
        GlassSampleGate { GlassBoard() }
        #else
        GlassBoard()
        #endif
    }
}
