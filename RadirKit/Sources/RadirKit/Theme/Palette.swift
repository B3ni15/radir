/// A Radír színei: lapos, papírszerű háttér (mint a Firkában), radírkék akcentus. A jegyszínek a legacy alapértékei.
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
        backgroundTop: ARGB(0xFFF4_F3EE), background: ARGB(0xFFF4_F3EE), surface: ARGB(0xFFFF_FFFF),
        text: ARGB(0xFF15_161A), secondaryText: ARGB(0xFF6B_6D75), separator: ARGB(0xFFE4_E2DB),
        grid: ARGB(0xFFE4_E2DB), warning: ARGB(0xFFFF_3B30), accent: ARGB(0xFF2F_6FEB),
        accentSoft: ARGB(0xFFE2_EAFC), paper: ARGB(0xFFFB_FAF6), grades: defaultGrades)

    public static let dark = Palette(
        backgroundTop: ARGB(0xFF0E_0F12), background: ARGB(0xFF0E_0F12), surface: ARGB(0xFF19_1A1F),
        text: ARGB(0xFFF3_F3F5), secondaryText: ARGB(0xFF9D_9FA7), separator: ARGB(0xFF28_292F),
        grid: ARGB(0xFF1F_2026), warning: ARGB(0xFFFF_453A), accent: ARGB(0xFF6C_9BFF),
        accentSoft: ARGB(0xFF1D_2A48), paper: ARGB(0xFF1F_1E24), grades: defaultGrades)
}
