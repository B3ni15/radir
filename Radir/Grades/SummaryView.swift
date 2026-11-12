import RadirKit
import SwiftUI

/// Év végi összefoglaló: jegyek, tantárgyak, hiányzások, és a „személyiséged” (a legacy szabályai szerint).
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let book = app.grades.book {
                    let s = YearSummary(book: book, absences: app.school.absences ?? [])
                    Text("Az éved a Radírban").font(.display(30)).multilineTextAlignment(.center).padding(.top, 8)
                    HStack(spacing: 10) {
                        stat("\(s.gradeCount)", "jegy")
                        stat("\(s.fives)", "ötös")
                        stat("\(s.absenceCount)", "hiányzott óra")
                    }
                    PanelGroup {
                        if let avg = s.average {
                            PanelRow(title: "Átlagod", systemImage: "chart.line.uptrend.xyaxis") { AverageBadge(value: avg) }
                        }
                        if let b = s.best {
                            PanelRow(title: "Legjobb tantárgy", subtitle: LocalizedStringKey(b.subject.name), systemImage: "trophy.fill",
                                     tint: Color(palette.gradeColor(5)!)) { AverageBadge(value: b.average) }
                        }
                        if let w = s.worst, w.subject.id != s.best?.subject.id {
                            PanelRow(title: "Ezen még dolgozhatsz", subtitle: LocalizedStringKey(w.subject.name), systemImage: "dumbbell.fill",
                                     tint: Color(palette.gradeColor(2)!)) { AverageBadge(value: w.average) }
                        }
                        if let m = s.mostCommon {
                            PanelRow(title: "Leggyakoribb jegyed", subtitle: "\(m.count) alkalommal", systemImage: "number") {
                                Text("\(m.grade)").font(.custom("Montserrat-Bold", size: 22)).foregroundStyle(Color(palette.gradeColor(m.grade)!))
                            }
                        }
                        if s.lateMinutes > 0 {
                            PanelRow("Összesen \(s.lateMinutes) perc késés", systemImage: "clock.badge.exclamationmark")
                        }
                    }
                    personality(s.personality)
                } else {
                    PanelGroup { PanelRow("Előbb töltsd be a jegyeidet", subtitle: "Nyisd meg a Jegyek fület.", systemImage: "bookmark") }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Összefoglaló")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await app.grades.load(app)
            await app.school.load(app)
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.custom("Montserrat-Bold", size: 26, relativeTo: .title)).foregroundStyle(Color(palette.accent))
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
        }
        .frame(maxWidth: .infinity)
        .radirPanel()
    }

    @ViewBuilder
    private func personality(_ p: YearSummary.Personality) -> some View {
        let (emoji, title, text) = Self.describe(p)
        Button { withAnimation(.spring(duration: 0.5)) { revealed = true } } label: {
            VStack(spacing: 10) {
                Text("A személyiséged").font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
                if revealed {
                    Text(emoji).font(.system(size: 64))
                    Text(title).font(.title(24, relativeTo: .title))
                    Text(text).font(.subheadline).foregroundStyle(Color(palette.secondaryText)).multilineTextAlignment(.center)
                } else {
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 56)).foregroundStyle(Color(palette.accent))
                    Text("Koppints a felfedéshez").font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .radirPanel()
        }
        .buttonStyle(.plain)
    }

    static func describe(_ p: YearSummary.Personality) -> (String, String, String) {
        switch p {
        case .geek: ("🤓", String(localized: "Okostojás"), String(localized: "Szinte minden tantárgyból kiváló vagy. Csak így tovább!"))
        case .fallible: ("📉", String(localized: "Nehéz év"), String(localized: "Több egyes is becsúszott. Jövőre jobb lesz!"))
        case .healthy: ("💪", String(localized: "Vasegészség"), String(localized: "Alig hiányoztál egész évben."))
        case .quitter: ("🏃", String(localized: "Lógós"), String(localized: "Sok az igazolatlan hiányzás. Vigyázz rá!"))
        case .late: ("⌛", String(localized: "Késős"), String(localized: "A busz mindig pont akkor késik, igaz?"))
        case .sick: ("🤒", String(localized: "Sokat beteg"), String(localized: "Sokat hiányoztál. Jobbulást!"))
        case .acceptable: ("🤏", String(localized: "Átmenő"), String(localized: "Sok a kettes, de átmentél."))
        case .average: ("👌", String(localized: "Arany középút"), String(localized: "Nem rossz, nem kiváló: pont jó."))
        case .diligent: ("💫", String(localized: "Szorgalmas"), String(localized: "Sok órai munkád volt, ez meg is látszik."))
        case .npc: ("⛰️", String(localized: "Titokzatos"), String(localized: "Annyira kiegyensúlyozott vagy, hogy nem tudtunk besorolni."))
        }
    }
}
