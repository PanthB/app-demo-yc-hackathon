import SwiftUI

private struct WordIndex: TextAttribute {
    let index: Int
}

/// Big type whose words fade in one after another: a white lead, then the rest in grey.
struct WordsText: View {
    let lead: String
    let rest: String
    var size: CGFloat = 28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    var body: some View {
        let leadWords = lead.split(separator: " ").map(String.init)
        let words = leadWords + rest.split(separator: " ").map(String.init)
        let text = words.enumerated().reduce(Text("")) { text, item in
            let (index, word) = item
            let piece = Text(index < words.count - 1 ? word + " " : word)
                .foregroundStyle(index < leadWords.count ? Color.white : Color.white.opacity(0.42))
                .customAttribute(WordIndex(index: index))
            return Text("\(text)\(piece)")
        }
        text
            .font(.system(size: size, weight: .semibold))
            .lineSpacing(1)
            .textRenderer(WordFade(progress: progress, count: words.count))
            .accessibilityLabel(words.joined(separator: " "))
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .easeOut(duration: 0.35 + 0.06 * Double(words.count))) {
                    progress = 1
                }
            }
    }
}

private struct WordFade: TextRenderer, Animatable {
    var progress: Double
    let count: Int

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let span = 0.55
        for line in layout {
            for run in line {
                let index = run[WordIndex.self]?.index ?? 0
                let begin = Double(index) / Double(max(count - 1, 1)) * (1 - span)
                let local = min(max((progress - begin) / span, 0), 1)
                var word = context
                word.opacity = local
                word.translateBy(x: 0, y: (1 - local) * 8)
                word.draw(run)
            }
        }
    }
}
