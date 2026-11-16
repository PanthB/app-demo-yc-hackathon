import SwiftUI

/// Draws each glyph rising into place with its own small spring, one after another, as progress runs 0 to 1.
struct RiseInText: TextRenderer, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var slices: [Text.Layout.RunSlice] = []
        for line in layout {
            for run in line {
                for slice in run {
                    slices.append(slice)
                }
            }
        }
        let spread = 0.45
        let count = max(slices.count - 1, 1)
        for (index, slice) in slices.enumerated() {
            let begin = Double(index) / Double(count) * spread
            let local = min(max((progress - begin) / (1 - spread), 0), 1)
            let settle = local >= 1 ? 1 : 1 - exp(-6 * local) * cos(9 * local)
            var glyph = context
            glyph.opacity = min(1, local * 2.2)
            glyph.translateBy(x: 0, y: (1 - settle) * 10)
            glyph.draw(slice)
        }
    }
}
