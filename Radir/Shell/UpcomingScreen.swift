import RadirKit
import SwiftUI

/// A még el nem készült fül: rövid leírás, alatta a leendő képernyő halvány váza.
struct UpcomingScreen: View {
    enum Kind { case grades, timetable, notes, absences }
    let kind: Kind
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelGroup {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: icon)
                            .font(.m(.title2, .semibold))
                            .foregroundStyle(Color(palette.accent))
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color(palette.accentSoft)))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hamarosan").font(.title(18, relativeTo: .headline))
                            Text(description).font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText))
                        }
                    }
                    .padding(16)
                }
                skeleton
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(16)
        }
        .radirScreenBackground()
    }

    private var icon: String {
        switch kind {
        case .grades: "bookmark.fill"
        case .timetable: "calendar"
        case .notes: "book.closed.fill"
        case .absences: "timer"
        }
    }

    private var description: LocalizedStringKey {
        switch kind {
        case .grades: "Itt lesznek a tantárgyaid, az átlagaid, a grafikon és a jegykalkulátor."
        case .timetable: "Itt lesz a heti órarended, a helyettesítésekkel és az elmaradó órákkal."
        case .notes: "Itt lesznek a házi feladatok, a számonkérések és a saját jegyzeteid."
        case .absences: "Itt lesznek a hiányzásaid és késéseid, tantárgyanként."
        }
    }

    @ViewBuilder private var skeleton: some View {
        switch kind {
        case .grades:
            PanelGroup(title: "Tantárgyaid") {
                ForEach(["Matematika", "Magyar nyelv", "Történelem", "Angol nyelv"], id: \.self) { name in
                    PanelRow(title: LocalizedStringKey(name), systemImage: "function") {
                        AverageBadge(value: 4.25)
                    }
                }
            }
        case .timetable:
            PanelGroup(title: "Hétfő") {
                ForEach(1..<6) { i in
                    PanelRow(title: "Óra neve", subtitle: "Terem", systemImage: "\(i).circle") { Text("8:00 – 8:45") }
                }
            }
        case .notes:
            PanelGroup(title: "Legutóbbi") {
                ForEach(0..<3) { _ in PanelRow("Házi feladat címe", subtitle: "Tantárgy · holnapra", systemImage: "house") }
            }
        case .absences:
            PanelGroup(title: "Tantárgyanként") {
                ForEach(0..<4) { _ in PanelRow(title: "Tantárgy", systemImage: "timer") { Text("3 óra") } }
            }
        }
    }
}
