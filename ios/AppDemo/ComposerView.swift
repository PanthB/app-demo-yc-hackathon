import ConvexMobile
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
                Section("Name") {
                    TextField("Your name", text: $author)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .author)
                        .accessibilityIdentifier("authorField")
                }
                Section("Moment") {
                    TextField("What's happening?", text: $text, axis: .vertical)
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
            .navigationTitle("New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") {
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
            logger.error("moments:add failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't post your moment. Try again."
        }
        isPosting = false
    }
}
