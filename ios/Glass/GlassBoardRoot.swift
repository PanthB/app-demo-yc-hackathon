import SwiftUI

struct GlassBoardRoot: View {
    var body: some View {
        Text("the glass board is on its way.")
            .font(.system(.title3, design: .rounded))
            .padding(24)
            .glassEffect()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("glassBoardStub")
    }
}
