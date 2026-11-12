import RadirKit
import SwiftUI

/// A KRÉTA tanulói adatlapja (a belépéskor letöltött adatokból).
struct StudentInfoView: View {
    let account: Account
    @Environment(\.palette) private var palette

    var body: some View {
        let s = account.student
        ScrollView {
            VStack(spacing: 18) {
                PanelGroup {
                    row("Név", s.name, "person")
                    row("Iskola", s.schoolName, "building.2")
                    row("Intézménykód", s.instituteCode, "number")
                    row("Felhasználónév", account.userName, "at")
                    if let birth = s.birthDate { row("Születési dátum", birth.formatted(date: .long, time: .omitted), "gift") }
                    if let address = s.address { row("Lakcím", address, "house") }
                    row("Szerep", account.role == .parent ? String(localized: "Gondviselő") : String(localized: "Tanuló"), "graduationcap")
                    if s.gradeDelayHours > 0 {
                        row("Jegyek késleltetése", String(localized: "\(s.gradeDelayHours) óra"), "clock.arrow.circlepath")
                    }
                }
                if !s.parents.isEmpty {
                    PanelGroup(title: "Gondviselők") {
                        ForEach(s.parents, id: \.self) { p in PanelRow(LocalizedStringKey(p), systemImage: "figure.2.and.child.holdinghands") }
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Személyes adatok")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: LocalizedStringKey, _ value: String, _ icon: String) -> some View {
        PanelRow(title: title, systemImage: icon) {
            Text(value).font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText)).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }
}
