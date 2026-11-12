import RadirKit
import SwiftUI

/// Lapos háttér, mint a Firkában; csak saját témánál lehet színátmenetes (`backgroundTop`).
struct RadirBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        LinearGradient(colors: [Color(palette.backgroundTop), Color(palette.background)],
                       startPoint: .top, endPoint: .init(x: 0.5, y: 0.45))
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
