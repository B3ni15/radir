import RadirKit
import SwiftUI

extension ContainerValues {
    /// Háttér nélküli sor egy `PanelGroup`-on belül (pl. szünet); a szomszédos kártyák sarka ehhez igazodik.
    @Entry var panelPlain = false
}

/// Egymásra rakott kártyák (a Firka „split panel”-je): kívül 18-as, belül 8-as sarok, 4 pont rés.
struct PanelGroup<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder var content: Content
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { SectionLabel(title) }
            Group(subviews: content) { subviews in
                let plain = subviews.map(\.containerValues.panelPlain)
                VStack(spacing: 4) {
                    ForEach(subviews.indices, id: \.self) { i in
                        if plain[i] {
                            subviews[i]
                        } else {
                            let shape = shape(first: i == 0 || plain[i - 1], last: i == subviews.count - 1 || plain[i + 1])
                            subviews[i]
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(palette.surface), in: shape)
                                .contentShape(shape)
                        }
                    }
                }
            }
        }
    }

    private func shape(first: Bool, last: Bool) -> UnevenRoundedRectangle {
        let top: CGFloat = first ? 18 : 8
        let bottom: CGFloat = last ? 18 : 8
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                                      bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous)
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    var trailing: Text?
    @Environment(\.palette) private var palette

    init(_ text: LocalizedStringKey, trailing: Text? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text).font(.m(.subheadline, .semibold))
            Spacer()
            trailing.font(.m(.subheadline))
        }
        .foregroundStyle(Color(palette.secondaryText))
        .padding(.horizontal, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Egy sor kártyán belül: kör alakú ikon, cím, alcím, jobb oldalt bármi.
struct PanelRow<Trailing: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var systemImage: String?
    var tint: Color?
    /// Csak a kijelentkezéshez és hasonló romboló műveletekhez: a cím is a tint színét kapja.
    var destructive = false
    @ViewBuilder var trailing: Trailing
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                // sima ikon, kör nélkül, mint a Firka listáiban
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint ?? Color(palette.text).opacity(0.75))
                    .frame(width: 26)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.m(.body, .semibold)).foregroundStyle(destructive ? (tint ?? Color(palette.warning)) : Color(palette.text))
                if let subtitle {
                    Text(subtitle).font(.m(.footnote)).foregroundStyle(Color(palette.secondaryText))
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // az egész sor koppintható legyen, ne csak a szöveg
        .contentShape(.rect)
    }
}

extension PanelRow {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String? = nil, tint: Color? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, destructive: false, trailing: trailing)
    }
}

extension PanelRow where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String? = nil, tint: Color? = nil,
         destructive: Bool = false) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, destructive: destructive) { EmptyView() }
    }
}

struct Chevron: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.m(.footnote, .semibold))
            .foregroundStyle(Color(palette.secondaryText).opacity(0.6))
            .accessibilityHidden(true)
    }
}

/// Szűrő chip, mint a Firka kezdőlapján.
struct Chip: View {
    let title: LocalizedStringKey
    var isSelected = false
    @Environment(\.palette) private var palette

    var body: some View {
        Text(title)
            .font(.m(.subheadline, .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color(palette.text))
            .background(Capsule().fill(isSelected ? Color(palette.accent) : Color(palette.surface)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Monogram egy teli, akcentusszínű körben.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    @Environment(\.palette) private var palette

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.custom("Montserrat-Bold", size: size * 0.38))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(palette.accent)))
            .accessibilityHidden(true)
    }
}

/// Jegyátlag: a saját halvány jegyszínű kapszulában (mint a Firkában), az osztályátlag (`filled`) csak szövegként.
struct AverageBadge: View {
    let value: Double
    var filled = false
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.roundingThreshold) private var threshold

    var body: some View {
        let color = Color(palette.gradeColor(Averages.roundedGrade(value, threshold: threshold)) ?? palette.accent)
        Text(value, format: .number.precision(.fractionLength(2)))
            .font(.m(.subheadline, .bold).monospacedDigit())
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(filled ? Color(palette.secondaryText) : color.gradeInk(scheme))
            .background(Capsule().fill(filled ? .clear : color.opacity(0.2)))
    }
}

extension Color {
    /// Jegyszín szövegnek: világosban sötétítve (a sárga különben olvashatatlan), sötétben eredeti.
    func gradeInk(_ scheme: ColorScheme) -> Color {
        scheme == .light ? mix(with: .black, by: 0.4) : self
    }
}

extension View {
    /// Egyedülálló kártya (nem csoportban).
    func radirPanel() -> some View { modifier(PanelModifier()) }

    /// Saját lebegő elem: iOS 26-tól Liquid Glass, előtte sima material.
    @ViewBuilder
    func radirGlass(in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }
}

private struct PanelModifier: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(palette.surface), in: .rect(cornerRadius: 18, style: .continuous))
    }
}
