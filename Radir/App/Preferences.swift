import Foundation
import Observation
import RadirKit
import SwiftUI

/// Az app beállításai (minden fióknak közös), a telefonon tárolva.
@Observable
final class Preferences {
    enum Appearance: String, CaseIterable { case system, light, dark }

    /// Akcentusszínek: a Radír kék, és a legacy választható színei.
    static let accents: [(name: LocalizedStringKey, light: ARGB, dark: ARGB)] = [
        ("Radír kék", ARGB(0xFF2F_6FEB), ARGB(0xFF6C_9BFF)),
        ("Ceruzapiros", ARGB(0xFFE5_484D), ARGB(0xFFFF_6B6F)),
        ("Filc zöld", ARGB(0xFF6E_A51A), ARGB(0xFFA7_DC22)),
        ("Türkiz", ARGB(0xFF14_9C8C), ARGB(0xFF2F_D3BD)),
        ("Narancs", ARGB(0xFFE2_6B12), ARGB(0xFFFF_9F4A)),
        ("Lila", ARGB(0xFF8E_44C9), ARGB(0xFFBF_7BF2)),
        ("Rózsaszín", ARGB(0xFFD6_3A7A), ARGB(0xFFFF_6FAE)),
    ]

    private let d = UserDefaults.standard

    var appearance: Appearance {
        didSet {
            d.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }
    var accentIndex: Int { didSet { d.set(accentIndex, forKey: "accentIndex") } }
    /// 1-es … 5-ös; nil: alap jegyszínek
    var gradeColors: [UInt32]? { didSet { d.set(gradeColors.map { $0.map(Int.init) }, forKey: "gradeColors") } }
    /// A jegyszín kerekítése (legacy: 0,5)
    var roundingThreshold: Double { didSet { d.set(roundingThreshold, forKey: "roundingThreshold") } }
    /// Csengetési eltolás másodpercben: ha az iskola órája siet vagy késik
    var bellDelay: Int { didSet { d.set(bellDelay, forKey: "bellDelay") } }
    var startTab: AppTab { didSet { d.set(startTab.rawValue, forKey: "startTab") } }
    /// Üres: a napszaknak megfelelő köszöntés. `%s` helyére a keresztnév kerül.
    var welcomeMessage: String { didSet { d.set(welcomeMessage, forKey: "welcomeMessage") } }
    var calendarSync: Bool { didSet { d.set(calendarSync, forKey: "calendarSync") } }
    /// Részletes testreszabás (mint a Firkában): bármilyen akcentus-, háttér-, kártya- és szövegszín.
    var customEnabled: Bool { didSet { d.set(customEnabled, forKey: "customEnabled") } }
    /// Kulcsok: accent, background, surface, text
    var customColors: [String: UInt32] { didSet { d.set(customColors.mapValues(Int.init), forKey: "customColors") } }

    init() {
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        accentIndex = min(d.integer(forKey: "accentIndex"), Self.accents.count - 1)
        gradeColors = (d.array(forKey: "gradeColors") as? [Int]).map { $0.map { UInt32($0) } }
        roundingThreshold = d.object(forKey: "roundingThreshold") as? Double ?? 0.5
        bellDelay = d.integer(forKey: "bellDelay")
        startTab = AppTab(rawValue: d.string(forKey: "startTab") ?? "") ?? .home
        welcomeMessage = d.string(forKey: "welcomeMessage") ?? ""
        calendarSync = d.bool(forKey: "calendarSync")
        customEnabled = d.bool(forKey: "customEnabled")
        customColors = (d.dictionary(forKey: "customColors") as? [String: Int])?.mapValues { UInt32($0) } ?? [:]
    }

    /// Az ablakra állítva, mert a `preferredColorScheme(nil)` sötétből nem vált vissza újraindítás nélkül.
    func applyAppearance() {
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }

    /// A Radír palettája a beállított akcentussal és jegyszínekkel.
    func palette(for scheme: ColorScheme) -> Palette {
        var p: Palette = scheme == .dark ? .dark : .light
        let a = Self.accents[accentIndex]
        p.accent = scheme == .dark ? a.dark : a.light
        p.accentSoft = p.accent.mixed(with: p.surface, by: scheme == .dark ? 0.7 : 0.85)
        if let g = gradeColors, g.count == 5 { p.grades = g.map(ARGB.init) }
        guard customEnabled else { return p }
        let c = customColors.mapValues(ARGB.init)
        if let v = c["accent"] { p.accent = v }
        if let v = c["background"] { p.background = v; p.paper = v }
        if let v = c["surface"] { p.surface = v }
        if let v = c["text"] { p.text = v }
        // a többi árnyalat a megadott színekből
        p.backgroundTop = p.background.mixed(with: p.accent, by: 0.12)
        p.secondaryText = p.text.mixed(with: p.surface, by: 0.4)
        p.separator = p.text.mixed(with: p.surface, by: 0.85)
        p.grid = p.backgroundTop.mixed(with: p.text, by: 0.08)
        p.accentSoft = p.accent.mixed(with: p.surface, by: 0.8)
        return p
    }

    /// Az idő, amihez az élő kártya és a Live Activity igazodik.
    var schoolNow: Date { .radirNow.addingTimeInterval(TimeInterval(bellDelay)) }
}

extension Date {
    /// Az app „most”-ja. DEBUG buildben a `-RadirClock 09:12` kapcsoló a mai nap adott percére rögzíti (képernyőképekhez).
    static var radirNow: Date {
        #if DEBUG
        if let hm = UserDefaults.standard.string(forKey: "RadirClock")?.split(separator: ":").compactMap({ Int($0) }), hm.count == 2,
           let fixed = Calendar.current.date(bySettingHour: hm[0], minute: hm[1], second: 0, of: .now) {
            return fixed
        }
        #endif
        return .now
    }
}
