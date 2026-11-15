import Combine
import ConvexMobile
import SwiftUI

struct MomentsView: View {
    @State private var moments: [Moment] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var attempt = 0
    @State private var isComposing = false

    var body: some View {
        NavigationStack {
            List(moments) { moment in
                MomentRow(moment: moment)
            }
            .listStyle(.plain)
            .animation(.default, value: moments)
            .accessibilityIdentifier("momentsList")
            .overlay { placeholder }
            .navigationTitle("Moments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isComposing = true
                    } label: {
                        Label("New moment", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("composeButton")
                }
            }
            .sheet(isPresented: $isComposing) {
                ComposerView()
            }
            .task(id: attempt) {
                await subscribe()
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if isLoading {
            ProgressView()
        } else if loadFailed {
            ContentUnavailableView {
                Label("Can't load moments", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try again") { attempt += 1 }
            }
        } else if moments.isEmpty {
            ContentUnavailableView(
                "No moments yet",
                systemImage: "sparkles",
                description: Text("Tap the pencil to share the first one.")
            )
        }
    }

    private func subscribe() async {
        isLoading = moments.isEmpty
        loadFailed = false
        do {
            for try await latest in convex.subscribe(to: "moments:list", yielding: [Moment].self).values {
                moments = latest
                isLoading = false
            }
        } catch {
            logger.error("moments:list subscription failed: \(String(describing: error), privacy: .public)")
            isLoading = false
            loadFailed = true
        }
    }
}

private struct MomentRow: View {
    let moment: Moment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(moment.text)
            Text("\(moment.author) · \(moment.date, format: .relative(presentation: .named))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
