import RadirKit
import SwiftUI

/// Tollkék tónusú füzetlap: színátmenet, fent halvány kockás vonalakkal.
struct RadirBackground: View {
    var gridHeight: CGFloat = 320
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(palette.backgroundTop), Color(palette.background)],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.45))
            GridLines(spacing: 24)
                .stroke(Color(palette.grid), lineWidth: 1)
                .frame(height: gridHeight)
                .mask(LinearGradient(colors: [.black.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

nonisolated struct GridLines: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for x in stride(from: rect.minX, through: rect.maxX, by: spacing) {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for y in stride(from: rect.minY, through: rect.maxY, by: spacing) {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

extension View {
    /// A képernyő háttere. Listáknál a rendszer háttere elrejtve.
    func radirScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { RadirBackground() }
    }
}
