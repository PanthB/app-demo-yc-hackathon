import ConvexMobile
import os
import SwiftUI

struct ComposerView: View {
    private enum Field { case author, text }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("author") private var author = ""
    @State private var text = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private var trimmedAuthor: String { author.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("name") {
                    TextField("your name", text: $author)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .author)
                        .accessibilityIdentifier("authorField")
                }
                Section("moment") {
                    TextField("what's happening?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focus, equals: .text)
                        .accessibilityIdentifier("momentField")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("new moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("post") {
                            Task { await post() }
                        }
                        .disabled(trimmedAuthor.isEmpty || trimmedText.isEmpty)
                        .accessibilityIdentifier("postButton")
                    }
                }
            }
            .interactiveDismissDisabled(isPosting)
            .onAppear {
                focus = trimmedAuthor.isEmpty ? .author : .text
            }
        }
    }

    private func post() async {
        isPosting = true
        errorMessage = nil
        do {
            try await convex.mutation("moments:add", with: ["text": trimmedText, "author": trimmedAuthor])
            dismiss()
        } catch {
            Logger.app.error("moments:add failed: \(String(describing: error), privacy: .public)")
            errorMessage = "that didn't go through, so give it another try."
        }
        isPosting = false
    }
}
