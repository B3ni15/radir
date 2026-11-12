import CoreText
import SwiftUI
import UIKit

enum RadirFont {
    /// A Montserrat a címekhez, mint a Firkában. A szövegtörzs SF marad.
    static func register() {
        for name in ["Montserrat-Bold", "Montserrat-ExtraBold", "Montserrat-SemiBold"] {
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
    static func display(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .custom("Montserrat-ExtraBold", size: size, relativeTo: style)
    }

    static func title(_ size: CGFloat, relativeTo style: TextStyle = .title2) -> Font {
        .custom("Montserrat-Bold", size: size, relativeTo: style)
    }
}
