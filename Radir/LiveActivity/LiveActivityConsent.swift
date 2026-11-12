import RadirKit
import SwiftUI

/// Mielőtt bármi a szerverre kerülne: mit küldünk, hova, és meddig marad ott.
struct LiveActivityConsent: View {
    let accept: () -> Void
    let cancel: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "platter.filled.top.iphone")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(palette.accent))
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color(palette.accentSoft)))
                    .padding(.top, 28)
                    .accessibilityHidden(true)
                Text("Live Activity").font(.title(26, relativeTo: .title))
                PanelGroup {
                    PanelRow("Mi ez?", subtitle: "A mostani órád, a terem és a hátralévő idő a zárolt képernyőn és a Dynamic Islandben, akkor is, ha a Radír zárva van.",
                             systemImage: "clock.fill")
                    PanelRow("Mi kerül a szerverre?", subtitle: "A mai óráid (tantárgy, terem, időpont, téma), egy véletlen eszközazonosító és az értesítési token. A neved, a KRÉTA belépésed és a jegyeid nem.",
                             systemImage: "server.rack")
                    PanelRow("Hova és meddig?", subtitle: "A Radír saját szerverére (legacy-la.devbeni.lol), titkosítva. Az utolsó óra után, vagy ha kikapcsolod, törlődik.",
                             systemImage: "lock.fill")
                }
                VStack(spacing: 10) {
                    Button(action: accept) {
                        Text("Bekapcsolom").font(.m(.body, .semibold)).frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .radirProminentButton()
                    Button("Mégse", action: cancel).font(.m(.body, .semibold))
                }
                .controlSize(.large)
            }
            .padding(20)
        }
        .radirScreenBackground()
        .presentationDetents([.large])
    }
}
