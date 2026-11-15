import SwiftUI

enum DropSuggestion: Equatable {
    case words(String)
    case soon(Date, lead: String)
}

struct SuggestionLine: View {
    let suggestion: DropSuggestion

    var body: some View {
        Group {
            switch suggestion {
            case .words(let words):
                Text(words)
            case .soon(let date, let lead):
                Text("\(lead) \(Text(.currentDate, format: .reference(to: date, allowedFields: [.hour, .minute], maxFieldCount: 1))).")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.tint)
        .lineLimit(2)
    }
}
