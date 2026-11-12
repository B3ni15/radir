import RadirKit
import SwiftUI

/// Kockás füzetlap, fent piros és kék firkákkal, mintha valaki kiradírozta volna őket.
struct LoginBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(palette.backgroundTop), Color(palette.background)], startPoint: .top, endPoint: .bottom)
            GridLines(spacing: 24)
                .stroke(Color(palette.grid), lineWidth: 1)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            Doodles()
                .frame(height: 260)
                .blur(radius: 0.6)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct Doodles: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let style = StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)

            var wave = Path()
            wave.move(to: CGPoint(x: w * 0.04, y: h * 0.30))
            wave.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.22), control1: CGPoint(x: w * 0.14, y: h * 0.05), control2: CGPoint(x: w * 0.28, y: h * 0.42))
            ctx.stroke(wave, with: .color(Color(palette.warning).opacity(0.28)), style: style)

            var loop = Path()
            loop.move(to: CGPoint(x: w * 0.60, y: h * 0.12))
            loop.addCurve(to: CGPoint(x: w * 0.74, y: h * 0.40), control1: CGPoint(x: w * 0.86, y: h * 0.02), control2: CGPoint(x: w * 0.94, y: h * 0.46))
            loop.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.30), control1: CGPoint(x: w * 0.60, y: h * 0.34), control2: CGPoint(x: w * 0.84, y: h * 0.18))
            ctx.stroke(loop, with: .color(Color(palette.accent).opacity(0.25)), style: style)

            var dash = Path()
            dash.move(to: CGPoint(x: w * 0.18, y: h * 0.52))
            dash.addLine(to: CGPoint(x: w * 0.30, y: h * 0.47))
            ctx.stroke(dash, with: .color(Color(palette.gradeColor(3)!).opacity(0.35)), style: style)

            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.86, y: h * 0.56, width: 14, height: 14)),
                     with: .color(Color(palette.gradeColor(5)!).opacity(0.4)))
        }
    }
}
