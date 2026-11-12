import RadirKit
import SwiftUI

extension Color {
    init(_ argb: ARGB) {
        self.init(.sRGB, red: argb.red, green: argb.green, blue: argb.blue, opacity: argb.alpha)
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .light
}

private struct ThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let palette: Palette = scheme == .dark ? .dark : .light
        content
            .environment(\.palette, palette)
            .tint(Color(palette.accent))
    }
}

extension View {
    /// A gyökérnézeten: a világos/sötét módhoz tartozó Radír palettát adja a nézeteknek.
    func radirTheme() -> some View { modifier(ThemeModifier()) }
}
