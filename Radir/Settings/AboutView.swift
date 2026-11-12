import RadirKit
import SwiftUI

struct AboutView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 84, height: 84)
                        .clipShape(.rect(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Radír").font(.display(30))
                    Text("Verzió \(AppModel.appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(Color(palette.secondaryText))
                }
                .padding(.top, 12)

                PanelGroup(title: "Család") {
                    PanelRow("Filc → reFilc → Firka → Radír",
                             subtitle: "A Radír a Filc, a reFilc és a Firka nyílt forrású munkájára épül. Köszönjük minden fejlesztőjüknek.",
                             systemImage: "heart.fill", tint: Color(palette.warning))
                    PanelRow(title: "Licenc", systemImage: "doc.text") { Text("AGPL-3.0").foregroundStyle(Color(palette.secondaryText)) }
                }

                PanelGroup(title: "Adatvédelem") {
                    PanelRow("A jelszavadat nem látjuk",
                             subtitle: "A belépés a KRÉTA saját oldalán történik. A tokenek csak a telefonod kulcskarikájában vannak.",
                             systemImage: "lock.fill")
                    PanelRow("Nem hivatalos alkalmazás",
                             subtitle: "A Radír nem áll kapcsolatban az e-KRÉTA fejlesztőjével.",
                             systemImage: "exclamationmark.shield.fill")
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Névjegy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
