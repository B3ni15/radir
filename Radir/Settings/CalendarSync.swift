import EventKit
import RadirKit

/// Az órarend egy saját „Radír” naptárba (a legacy naptárszinkronja): a mostani és a jövő hét órái.
enum CalendarSync {
    private static let store = EKEventStore()
    private static let calendarKey = "radirCalendarID"

    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    private static func calendar() throws -> EKCalendar {
        if let id = UserDefaults.standard.string(forKey: calendarKey), let c = store.calendar(withIdentifier: id) { return c }
        let c = EKCalendar(for: .event, eventStore: store)
        c.title = "Radír"
        c.cgColor = CGColor(red: 0.18, green: 0.44, blue: 0.92, alpha: 1)
        c.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first { $0.sourceType == .local }
        try store.saveCalendar(c, commit: true)
        UserDefaults.standard.set(c.calendarIdentifier, forKey: calendarKey)
        return c
    }

    /// A megadott hetek eseményeit lecseréli az órákra (elmaradt órák nélkül). Csak a saját naptárához nyúl.
    static func sync(_ weeks: [SchoolWeek: [Lesson]]) throws {
        guard hasAccess, !weeks.isEmpty else { return }
        let cal = try calendar()
        for (week, lessons) in weeks {
            let range = store.predicateForEvents(withStart: week.start, end: week.end.addingTimeInterval(86_400), calendars: [cal])
            for e in store.events(matching: range) { try store.remove(e, span: .thisEvent, commit: false) }
            for l in lessons where !l.isCancelled && !l.isEvent {
                let e = EKEvent(eventStore: store)
                e.calendar = cal
                e.title = l.index.map { "\($0). \(l.title)" } ?? l.title
                e.startDate = l.start
                e.endDate = l.end
                e.location = l.room.isEmpty ? nil : l.room
                e.notes = [l.substituteTeacher.map { String(localized: "Helyettes: \($0)") } ?? l.teacher, l.topic].filter { !$0.isEmpty }.joined(separator: "\n")
                try store.save(e, span: .thisEvent, commit: false)
            }
        }
        try store.commit()
    }

    /// Kikapcsoláskor a Radír naptár törlődik.
    static func removeCalendar() {
        guard hasAccess, let id = UserDefaults.standard.string(forKey: calendarKey), let c = store.calendar(withIdentifier: id) else { return }
        try? store.removeCalendar(c, commit: true)
        UserDefaults.standard.removeObject(forKey: calendarKey)
    }
}
