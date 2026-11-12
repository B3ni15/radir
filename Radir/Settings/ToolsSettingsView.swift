import RadirKit
import SwiftUI

/// Naptárszinkron és jegyexport.
struct ToolsSettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var exportURL: URL?
    @State private var status: LocalizedStringKey?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PanelGroup(title: "Naptár") {
                    PanelRow(title: "Órarend a naptárban", subtitle: "A mostani és a jövő heti órák egy külön „Radír” naptárba kerülnek.",
                             systemImage: "calendar.badge.plus") {
                        Toggle("Naptárszinkron", isOn: calendarBinding).labelsHidden()
                    }
                    if app.prefs.calendarSync {
                        Button { Task { await syncNow() } } label: { PanelRow("Szinkronizálás most", systemImage: "arrow.triangle.2.circlepath") }
                            .buttonStyle(.plain)
                    }
                }

                PanelGroup(title: "Jegyek") {
                    if let exportURL {
                        ShareLink(item: exportURL) { PanelRow("Jegyek exportálása", subtitle: "JSON fájl, a reFilc/Firka formátumában.", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.plain)
                    } else {
                        PanelRow("Jegyek exportálása", subtitle: "Előbb töltsd be a jegyeidet a Jegyek fülön.", systemImage: "square.and.arrow.up")
                    }
                }

                if let status {
                    Text(status).font(.footnote).foregroundStyle(Color(palette.secondaryText)).padding(.horizontal, 6)
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Eszközök")
        .navigationBarTitleDisplayMode(.inline)
        .task { prepareExport() }
    }

    private var calendarBinding: Binding<Bool> {
        Binding(get: { app.prefs.calendarSync }, set: { on in
            Task {
                if on {
                    guard await CalendarSync.requestAccess() else {
                        status = "A Radír nem kapott hozzáférést a naptárhoz. A Beállítások appban engedélyezheted."
                        return
                    }
                    app.prefs.calendarSync = true
                    await syncNow()
                } else {
                    app.prefs.calendarSync = false
                    CalendarSync.removeCalendar()
                    status = "A Radír naptár törölve."
                }
            }
        })
    }

    private func syncNow() async {
        let now = SchoolWeek(containing: .now)
        await app.timetable.load(app, week: now)
        await app.timetable.load(app, week: now.next)
        do {
            try CalendarSync.sync(app.timetable.lessons.filter { $0.key == now || $0.key == now.next })
            status = "Az órarend bekerült a naptárba."
        } catch {
            status = "Nem sikerült a naptárba írni."
        }
    }

    private func prepareExport() {
        guard let grades = app.grades.book?.grades, !grades.isEmpty, let data = try? GradeExport.json(grades) else { return }
        let url = FileManager.default.temporaryDirectory.appending(path: "radir-jegyek.json")
        if (try? data.write(to: url)) != nil { exportURL = url }
    }
}
