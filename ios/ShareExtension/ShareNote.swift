import SwiftUI

struct ShareNote: View {
    @ObservedObject var state: ShareState
    var boardName: String?
    var close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var line: String {
        switch state.outcome {
        case .none: "hang on, i'm grabbing it."
        case .dropped: boardName.map { "dropped it in \($0)." } ?? "dropped it, i'll find it a spot."
        case .failed: "i couldn't hold on to that one, so please try sharing it again."
        }
    }

    var body: some View {
        ZStack {
            Color.clear
            HStack(spacing: 12) {
                switch state.outcome {
                case .none:
                    ProgressView()
                case .dropped:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, value: state.outcome)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                Text(line)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .animation(.snappy, value: state.outcome)
            .scaleEffect(state.isLeaving && !reduceMotion ? 0.9 : 1)
            .opacity(state.isLeaving ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: state.isLeaving)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(line)
            .accessibilityIdentifier("shareConfirmation")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.outcome != nil { close() }
        }
    }
}
