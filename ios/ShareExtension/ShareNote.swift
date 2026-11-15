import SwiftUI

struct ShareNote: View {
    @ObservedObject var state: ShareState
    var boardName: String?
    var close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isShowing: Bool {
        state.outcome != nil || state.isTakingAWhile
    }

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
            .scaleEffect(isShowing || reduceMotion ? 1 : 0.9)
            .opacity(isShowing ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: isShowing)
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
