import SwiftUI

struct GlassWindowFrame: Shape {
    var window: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 4, style: .continuous)
        path.addRect(window)
        return path
    }
}

struct GlassWaveform: Shape {
    private static let points: [CGPoint] = [
        CGPoint(x: 3, y: 16), CGPoint(x: 8, y: 13), CGPoint(x: 11, y: 19), CGPoint(x: 15, y: 9),
        CGPoint(x: 19, y: 23), CGPoint(x: 23, y: 6), CGPoint(x: 27, y: 26), CGPoint(x: 31, y: 11),
        CGPoint(x: 35, y: 20), CGPoint(x: 39, y: 14), CGPoint(x: 43, y: 18), CGPoint(x: 47, y: 5),
        CGPoint(x: 51, y: 27), CGPoint(x: 55, y: 8), CGPoint(x: 59, y: 24), CGPoint(x: 63, y: 12),
        CGPoint(x: 67, y: 19), CGPoint(x: 71, y: 15), CGPoint(x: 75, y: 17), CGPoint(x: 79, y: 7),
        CGPoint(x: 83, y: 25), CGPoint(x: 87, y: 10), CGPoint(x: 91, y: 22), CGPoint(x: 95, y: 13),
        CGPoint(x: 99, y: 19), CGPoint(x: 103, y: 11), CGPoint(x: 107, y: 20), CGPoint(x: 111, y: 15),
        CGPoint(x: 117, y: 16),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 120
        let sy = rect.height / 32
        for (index, point) in Self.points.enumerated() {
            let scaled = CGPoint(x: rect.minX + point.x * sx, y: rect.minY + point.y * sy)
            if index == 0 {
                path.move(to: scaled)
            } else {
                path.addLine(to: scaled)
            }
        }
        return path
    }
}

struct GlassTornSlip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let teeth = 14
        let step = rect.width / CGFloat(teeth)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 4))
        for tooth in 1...teeth {
            let x = rect.minX + step * CGFloat(tooth)
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.minY + (tooth % 2 == 0 ? 2 : 6)))
            path.addLine(to: CGPoint(x: x, y: rect.minY + 4))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        for tooth in 1...teeth {
            let x = rect.maxX - step * CGFloat(tooth)
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.maxY - (tooth % 2 == 0 ? 6 : 2)))
            path.addLine(to: CGPoint(x: x, y: rect.maxY - 4))
        }
        path.closeSubpath()
        return path
    }
}

struct GlassNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fold: CGFloat = 30
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 3))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - fold))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}

struct GlassNoteFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fold: CGFloat = 30
        path.move(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - fold))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY - fold + 4))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}
