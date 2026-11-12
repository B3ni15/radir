/// A Radír színei: tollkék tónusú füzetlap. A jegyszínek a legacy alapértékei.
public struct Palette: Sendable, Equatable {
    /// A háttér színátmenete fentről lefelé.
    public var backgroundTop: ARGB
    public var background: ARGB
    /// Kártya
    public var surface: ARGB
    public var text: ARGB
    public var secondaryText: ARGB
    public var separator: ARGB
    /// Kockás füzet vonalai
    public var grid: ARGB
    public var warning: ARGB
    public var accent: ARGB
    /// Az akcentus halvány változata: kiválasztott chip, ikon háttér
    public var accentSoft: ARGB
    public var paper: ARGB
    /// 0. elem = egyes, 4. elem = ötös
    public var grades: [ARGB]

    public func gradeColor(_ grade: Int) -> ARGB? {
        (1...5).contains(grade) ? grades[grade - 1] : nil
    }

    /// Átlaghoz tartozó szín: a két szomszédos jegyszín között mosva, mint a legacy grafikonján.
    public func gradeColor(forAverage avg: Double) -> ARGB {
        let a = min(max(avg, 1), 5)
        let lo = Int(a.rounded(.down)), hi = min(lo + 1, 5)
        return grades[lo - 1].mixed(with: grades[hi - 1], by: a - Double(lo))
    }

    public static let defaultGrades = [0xFFFF_54A1, 0xFFFF_A046, 0xFFF9_CF00, 0xFF92_EA3B, 0xFF22_CCAD].map(ARGB.init)

    public static let light = Palette(
        backgroundTop: ARGB(0xFFD9_E4FA), background: ARGB(0xFFEF_F3FB), surface: ARGB(0xFFF9_FBFF),
        text: ARGB(0xFF16_1A2A), secondaryText: ARGB(0xFF5C_6376), separator: ARGB(0xFFDD_E3F0),
        grid: ARGB(0xFFCF_DBF3), warning: ARGB(0xFFE5_484D), accent: ARGB(0xFF2F_6FEB),
        accentSoft: ARGB(0xFFDC_E7FD), paper: ARGB(0xFFFB_FAF6), grades: defaultGrades)

    public static let dark = Palette(
        backgroundTop: ARGB(0xFF15_1C33), background: ARGB(0xFF0D_1018), surface: ARGB(0xFF1A_1F2E),
        text: ARGB(0xFFF2_F3F8), secondaryText: ARGB(0xFFA3_A9BA), separator: ARGB(0xFF29_3045),
        grid: ARGB(0xFF20_2840), warning: ARGB(0xFFFF_6B6F), accent: ARGB(0xFF6C_9BFF),
        accentSoft: ARGB(0xFF22_3460), paper: ARGB(0xFF1F_1E24), grades: defaultGrades)
}
