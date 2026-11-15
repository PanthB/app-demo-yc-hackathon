import ConvexMobile
import os
import SwiftUI

struct MomentsView: View {
    @State private var moments: [Moment] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var attempt = 0
    @State private var isComposing = false

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                SkeletonCheckSection()
                #endif
                Section("moments") {
                    if isLoading && moments.isEmpty {
                        ProgressView()
                    } else if loadFailed {
                        Button("the board couldn't reach the backend, tap to try again") { attempt += 1 }
                    } else if moments.isEmpty {
                        Text("nothing here yet, so tap the pencil to share the first one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(moments) { moment in
                        MomentRow(moment: moment)
                    }
                }
            }
            .animation(.default, value: moments)
            .accessibilityIdentifier("momentsList")
            .navigationTitle("moments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isComposing = true
                    } label: {
                        Label("new moment", systemImage: "square.and.pencil")
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

    private func subscribe() async {
        isLoading = true
        loadFailed = false
        do {
            for try await latest in convex.subscribe(to: "moments:list", yielding: [Moment].self).values {
                moments = latest
                isLoading = false
            }
        } catch {
            Logger.app.error("moments:list subscription failed: \(String(describing: error), privacy: .public)")
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
