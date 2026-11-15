import os
import SwiftUI

struct BoardEntrySheet: View {
    let entry: BoardEntry
    @Environment(BoardsStore.self) private var boards
    @Environment(\.dismiss) private var dismiss
    @State private var boardName = ""
    @State private var code = ""
    @State private var name = ""
    @State private var problem: String?
    @State private var isWorking = false

    private var isCreating: Bool { entry == .create }

    private var canGo: Bool {
        let answer = (isCreating ? boardName : code).trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = boards.personName != nil || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !answer.isEmpty && hasName && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isCreating {
                        TextField("what's the board called?", text: $boardName)
                            .accessibilityIdentifier("boardNameField")
                    } else {
                        TextField("the invite code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("inviteCodeField")
                    }
                } footer: {
                    Text(isCreating
                        ? "everyone you invite can add to it, pin things and move them around."
                        : "it's the six letters and numbers a friend sent you.")
                }
                if boards.personName == nil {
                    Section {
                        TextField("your name", text: $name)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("personNameField")
                    } footer: {
                        Text("this is how your friends see who saved what.")
                    }
                }
                if let problem {
                    Section {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("boardEntryProblem")
                    }
                }
            }
            .navigationTitle(isCreating ? "new board" : "join a board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("never mind") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "make it" : "join") { go() }
                        .disabled(!canGo)
                        .accessibilityIdentifier("boardEntryConfirm")
                }
            }
            .onAppear {
                if case let .join(invited?) = entry { code = invited }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func go() {
        isWorking = true
        problem = nil
        Task {
            do {
                if isCreating {
                    try await boards.create(named: boardName.trimmingCharacters(in: .whitespacesAndNewlines), as: name)
                } else {
                    try await boards.join(code: code, as: name)
                }
                dismiss()
            } catch let known as BoardProblem {
                problem = known.message
            } catch {
                problem = "that didn't go through, so please try again in a moment."
                Logger.sync.error("couldn't \(isCreating ? "create" : "join", privacy: .public) a board: \(String(describing: error), privacy: .public)")
            }
            isWorking = false
        }
    }
}
