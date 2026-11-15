import SwiftUI

enum DropSuggestion: Equatable {
    case words(String)
    case startsSoon(Date)
}

struct SuggestionLine: View {
    let suggestion: DropSuggestion

    var body: some View {
        Group {
            switch suggestion {
            case .words(let words):
                Text(words)
            case .startsSoon(let date):
                Text("starts \(Text(.currentDate, format: .reference(to: date, allowedFields: [.hour, .minute], maxFieldCount: 1))).")
            }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
        .lineLimit(2)
    }
}
