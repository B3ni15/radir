import RadirKit
import SwiftUI

/// Első használatkor: mi hol van, a végén a Live Activity bekapcsolása.
struct OnboardingView: View {
    let finish: () -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var page = 0

    private struct Page {
        let icon: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
        let tips: [(String, LocalizedStringKey)]
    }

    private let pages: [Page] = [
        Page(icon: "house.fill", title: "Kezdőlap",
             text: "Itt látod, mi van most és mi jön, napokra bontva.",
             tips: [("clock.fill", "A mai órád visszaszámlálással; koppints rá, és megnyílik az órarendben."),
                    ("line.3.horizontal.decrease.circle", "A chipekkel szűrhetsz: jegyek, feladatok, számonkérések, hiányzások, beírások.")]),
        Page(icon: "bookmark.fill", title: "Jegyek",
             text: "Az átlagod, az osztályátlag és a grafikon egy helyen.",
             tips: [("chart.line.uptrend.xyaxis", "Az időszakválasztóval megnézheted, hogyan változott az átlagod."),
                    ("hand.tap.fill", "Egy tantárgyra koppintva látod az összes jegyét.")]),
        Page(icon: "calendar", title: "Órarend",
             text: "A heti órarended, a helyettesítésekkel és az elmaradó órákkal.",
             tips: [("hand.draw.fill", "Húzd oldalra a napok közti lapozáshoz."),
                    ("cup.and.saucer.fill", "A mostani óra körüli szüneteket is mutatja.")]),
        Page(icon: "book.closed.fill", title: "Füzet",
             text: "Házi feladatok, számonkérések, beírások, saját jegyzetek és teendők.",
             tips: [("checkmark.circle.fill", "A kész házit megjelölheted, és eltűnik a listáról."),
                    ("square.and.pencil", "A jegyzeteid csak a telefonodon vannak.")]),
        Page(icon: "timer", title: "Hiányzások",
             text: "Igazolt, igazolandó és igazolatlan hiányzások, késések, tantárgyanként.",
             tips: []),
        Page(icon: "person.crop.circle.fill", title: "Profil",
             text: "A jobb felső sarokban: fiókok, Live Activity és a többi beállítás.",
             tips: [("person.2.fill", "Több fiókot is hozzáadhatsz, és egy koppintással válthatsz.")]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Kihagyás", action: finish).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in pageView(pages[i]).tag(i) }
                liveActivityPage.tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if page < pages.count {
                Button {
                    withAnimation(.snappy) { page += 1 }
                } label: {
                    Text("Tovább").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
                }
                .radirProminentButton()
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background { LoginBackground() }
    }

    private func pageView(_ p: Page) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: p.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(Color(palette.accent).gradient))
                    .shadow(color: Color(palette.accent).opacity(0.35), radius: 16, y: 8)
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                Text(p.title).font(.display(34))
                Text(p.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(palette.secondaryText))
                    .multilineTextAlignment(.center)
                if !p.tips.isEmpty {
                    PanelGroup {
                        ForEach(p.tips.indices, id: \.self) { i in
                            PanelRow(p.tips[i].1, systemImage: p.tips[i].0)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }

    private var liveActivityPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "platter.filled.top.iphone")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(Color(palette.accent).gradient))
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                Text("Live Activity").font(.display(34))
                Text("A mostani órád, a szünet és a következő óra a zárolt képernyőn és a Dynamic Islandben.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(palette.secondaryText))
                    .multilineTextAlignment(.center)
                PanelGroup {
                    PanelRow("Mi kerül a szerverre?", subtitle: "A mai óráid (tantárgy, terem, időpont, téma), egy véletlen eszközazonosító és az értesítési token. A neved, a KRÉTA belépésed és a jegyeid nem.",
                             systemImage: "server.rack")
                    PanelRow("Hova és meddig?", subtitle: "A Radír saját szerverére (legacy-la.devbeni.lol), titkosítva. Az utolsó óra után, vagy ha kikapcsolod, törlődik.",
                             systemImage: "lock.fill")
                }
                VStack(spacing: 10) {
                    Button {
                        if let id = app.current?.id { app.liveActivity.setEnabled(true, for: id) }
                        Task { await app.liveActivity.sync(app: app) }
                        finish()
                    } label: {
                        Text("Bekapcsolom").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .radirProminentButton()
                    Button("Most nem", action: finish).font(.body.weight(.semibold))
                    Text("Később a profilodban is bekapcsolhatod.")
                        .font(.footnote).foregroundStyle(Color(palette.secondaryText))
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }
}
