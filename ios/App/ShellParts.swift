import SwiftUI
import UIKit

enum ShellTint {
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0x6B / 255.0, blue: 0x4A / 255.0, alpha: 1)
            : UIColor(red: 0xC9 / 255.0, green: 0x47 / 255.0, blue: 0x2B / 255.0, alpha: 1)
    })
}

struct ShellBar: View {
    let mode: ViewMode
    let choose: (ViewMode) -> Void
    @Namespace private var thumb

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(ViewMode.allCases, id: \.self) { option in
                        Button {
                            choose(option)
                        } label: {
                            Image(systemName: option.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(option == mode ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                                .frame(width: 52, height: 40)
                                .background {
                                    if option == mode {
                                        Capsule().fill(.tint).matchedGeometryEffect(id: "thumb", in: thumb)
                                    }
                                }
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.rawValue)
                        .accessibilityAddTraits(option == mode ? .isSelected : [])
                        .accessibilityIdentifier("view-\(option.rawValue)")
                    }
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer()

                AddMenu()
                    .font(.title3.weight(.semibold))
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

struct ShellMemberStack: View {
    let members: [RemoteMember]

    var body: some View {
        HStack(spacing: -6) {
            ForEach(members.prefix(4)) { member in
                PersonAvatar(member: member)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            }
        }
    }
}

struct ShellMembersSheet: View {
    let board: RemoteBoard

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(board.members) { member in
                        HStack(spacing: 12) {
                            PersonAvatar(member: member)
                            Text(member.name)
                        }
                    }
                }
                if let link = board.inviteLink, let code = board.inviteCode {
                    Section {
                        ShareLink(item: link, subject: Text(board.name), message: Text("come join \(board.name) with me.")) {
                            Label("invite a friend", systemImage: "person.badge.plus")
                        }
                    } footer: {
                        Text("they can also join by typing the code \(code).")
                    }
                }
            }
            .navigationTitle("people in \(board.name)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

extension PersonAvatar {
    init(member: RemoteMember) {
        name = member.name
        colorName = member.color
        personId = member.personId
    }
}

struct ShellToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .accessibilityIdentifier("arrivalToast")
    }

    static func words(for drop: Drop) -> String {
        let word = drop.kind.word
        let article = word.first.map { "aeiou".contains($0) } == true ? "an" : "a"
        return "\(CardWords.clean(drop.authorName) ?? "someone") added \(article) \(word)."
    }
}
