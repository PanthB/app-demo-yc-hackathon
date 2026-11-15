import SwiftUI

struct EmptyBoard: View {
    var body: some View {
        ContentUnavailableView {
            Label("nothing here yet.", systemImage: "tray")
        } description: {
            Text("share a song, a place or a clip from any app and it'll land here.")
        }
    }
}
