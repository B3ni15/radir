import Foundation
import Observation
import RadirKit

/// Hetenként letöltött órarend, gyorsítótárral.
@Observable
final class TimetableModel {
    var week = SchoolWeek(containing: .now)
    private(set) var lessons: [SchoolWeek: [Lesson]] = [:]
    private(set) var loading: Set<SchoolWeek> = []

    func days(for week: SchoolWeek) -> [TimetableDay] { Timetable.days(lessons[week] ?? []) }

    func day(_ date: Date) -> TimetableDay? {
        let start = Calendar.school.startOfDay(for: date)
        return days(for: SchoolWeek(containing: date)).first { $0.date == start }
    }

    func hasLoaded(_ week: SchoolWeek) -> Bool { lessons[week] != nil }

    /// Az aktuális hét, utána a következő is, hogy lapozáskor már meglegyen.
    func loadAround(_ app: AppModel, week: SchoolWeek) async {
        await load(app, week: week)
        await load(app, week: week.next)
    }

    func load(_ app: AppModel, week: SchoolWeek) async {
        guard let account = app.current else { return }
        if account.isDemo {
            lessons[week] = Demo.lessons(for: week)
            return
        }
        let key = "timetable-\(week.start.formatted(.iso8601.year().month().day()))"
        if lessons[week] == nil { lessons[week] = app.cache.load([Lesson].self, as: key, for: account.id) }
        guard let session = app.session(for: account), !loading.contains(week) else { return }
        loading.insert(week)
        defer { loading.remove(week) }
        do {
            // külön Task: ha a nézet eltűnik (fülváltás), a letöltés akkor is befejeződik
            let institute = account.instituteCode
            let fresh = try await Task { try await TimetableService().fetch(session: session, instituteCode: institute, week: week) }.value
            lessons[week] = fresh
            try? app.cache.save(fresh, as: key, for: account.id)
        } catch KretaError.reloginRequired {
            // teljes képernyős újra belépés jön, a tárolt adat addig is látszik
            app.markNeedsRelogin(account.id)
        } catch {
            // offline vagy KRÉTA hiba: csendben a tárolt adat marad
        }
    }
}
