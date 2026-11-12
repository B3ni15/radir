import CoreText
import SwiftUI
import UIKit

enum RadirFont {
    /// Minden szöveg Montserrat, mint a Firkában.
    static func register() {
        for name in ["Montserrat-Regular", "Montserrat-Medium", "Montserrat-SemiBold", "Montserrat-Bold", "Montserrat-ExtraBold"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        let nav = UINavigationBar.appearance()
        if let large = UIFont(name: "Montserrat-Bold", size: 32) {
            nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
        if let small = UIFont(name: "Montserrat-Bold", size: 17) {
            nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: small)]
        }
    }
}

extension Font {
    /// Montserrat a rendszer szövegstílusaihoz igazítva (a Montserrat szélesebb, ezért kicsit kisebb méretekkel).
    static func m(_ style: TextStyle, _ weight: Weight? = nil) -> Font {
        let (size, standard): (CGFloat, Weight) = switch style {
        case .largeTitle: (32, .bold)
        case .title: (26, .bold)
        case .title2: (21, .bold)
        case .title3: (19, .semibold)
        case .headline: (16, .bold)
        case .callout: (15, .medium)
        case .subheadline: (14, .medium)
        case .footnote: (12.5, .medium)
        case .caption: (11.5, .medium)
        case .caption2: (10.5, .semibold)
        default: (16, .medium)
        }
        return .custom(montserrat(weight ?? standard), size: size, relativeTo: style)
    }

    private static func montserrat(_ weight: Weight) -> String {
        switch weight {
        case .black, .heavy: "Montserrat-ExtraBold"
        case .bold: "Montserrat-Bold"
        case .semibold: "Montserrat-SemiBold"
        case .medium: "Montserrat-Medium"
        default: "Montserrat-Regular"
        }
    }

    static func display(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .custom("Montserrat-ExtraBold", size: size, relativeTo: style)
    }

    static func title(_ size: CGFloat, relativeTo style: TextStyle = .title2) -> Font {
        .custom("Montserrat-Bold", size: size, relativeTo: style)
    }
}
