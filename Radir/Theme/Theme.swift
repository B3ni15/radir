import RadirKit
import SwiftUI

extension Color {
    init(_ argb: ARGB) {
        self.init(.sRGB, red: argb.red, green: argb.green, blue: argb.blue, opacity: argb.alpha)
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .light
    /// A jegyszín kerekítési küszöbe (beállítható)
    @Entry var roundingThreshold: Double = 0.5
}

private struct ThemeModifier: ViewModifier {
    let prefs: Preferences
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let palette = prefs.palette(for: scheme)
        // saját színeknél a háttér fényessége dönti el, világos vagy sötét a felület
        let effective: ColorScheme = prefs.customEnabled ? (palette.background.luminance < 0.5 ? .dark : .light) : scheme
        content
            .environment(\.palette, palette)
            .environment(\.colorScheme, effective)
            // csak saját színeknél: különben a rendszer alapszíne (és a gombok akcentusa) marad
            .foregroundStyle(prefs.customEnabled ? AnyShapeStyle(Color(palette.text)) : AnyShapeStyle(.primary))
            .environment(\.roundingThreshold, prefs.roundingThreshold)
            .tint(Color(palette.accent))
            .font(.m(.body))
    }
}

extension View {
    /// A gyökérnézeten: a világos/sötét módhoz és a beállításokhoz tartozó Radír palettát adja a nézeteknek.
    func radirTheme(_ prefs: Preferences) -> some View {
        modifier(ThemeModifier(prefs: prefs)).onAppear { prefs.applyAppearance() }
    }
}
