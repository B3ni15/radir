import Foundation

public enum FeedEntry: Hashable, Identifiable, Sendable {
    case grade(Grade)
    case change(Lesson)
    case homework(Homework)
    case exam(Exam)
    case absence(Absence)
    case note(SchoolNote)

    public var id: String {
        switch self {
        case .grade(let g): "g-\(g.id)"
        case .change(let l): "l-\(l.id)"
        case .homework(let h): "h-\(h.id)"
        case .exam(let e): "e-\(e.id)"
        case .absence(let a): "a-\(a.id)"
        case .note(let n): "n-\(n.id)"
        }
    }

    /// Mikor történt (ehhez a naphoz kerül a hírfolyamban), és a napon belüli sorrend.
    var moment: Date {
        switch self {
        case .grade(let g): g.writeDate
        case .change(let l): l.start
        case .homework(let h): h.recorded ?? h.assigned ?? h.deadline
        case .exam(let e): e.announced ?? e.date
        case .absence(let a): a.lessonStart ?? a.date
        case .note(let n): n.recorded ?? n.date
        }
    }

    /// Napon belül: előbb a változások, aztán a többi a legújabb elöl.
    var rank: Int { if case .change = self { 0 } else { 1 } }
}

/// A hírfolyam nyersanyaga; ami hiányzik, az üres.
public struct FeedSources: Sendable {
    public var grades: [Grade] = []
    public var changes: [Lesson] = []
    public var homework: [Homework] = []
    public var exams: [Exam] = []
    public var absences: [Absence] = []
    public var notes: [SchoolNote] = []
    public init() {}
}

public struct FeedDay: Hashable, Identifiable, Sendable {
    /// Budapesti éjfél
    public let date: Date
    public let entries: [FeedEntry]
    public var id: Date { date }
}

/// A kezdőlap hírfolyamának válogatása.
public enum HomeFeed {
    /// Napokra bontva, a legkésőbbi nap elöl (a holnapi változás a mai fölött); napon belül előbb a változások
    /// időrendben, aztán a jegyek a legújabb elöl. Mint a Firka kezdőlapja.
    public static func days(grades: [Grade], changes: [Lesson]) -> [FeedDay] {
        var s = FeedSources()
        s.grades = grades
        s.changes = changes
        return days(s)
    }

    public static func days(_ s: FeedSources) -> [FeedDay] {
        let entries = s.grades.map(FeedEntry.grade) + s.changes.map(FeedEntry.change) + s.homework.map(FeedEntry.homework)
            + s.exams.map(FeedEntry.exam) + s.absences.map(FeedEntry.absence) + s.notes.map(FeedEntry.note)
        let byDay = Dictionary(grouping: entries) { Calendar.school.startOfDay(for: $0.moment) }
        return byDay.keys.sorted(by: >).map { day in
            FeedDay(date: day, entries: byDay[day]!.sorted { a, b in
                if a.rank != b.rank { return a.rank < b.rank }
                return a.rank == 0 ? a.moment < b.moment : a.moment > b.moment
            })
        }
    }

    /// Az utóbbi `days` nap eseményei (a jövőbeliek nem).
    public static func recent<T>(_ items: [T], now: Date, days: Int = 30, at: (T) -> Date) -> [T] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return items.filter { (cutoff...now).contains(at($0)) }
    }

    /// Az utóbbi `days` nap beírt jegyei, a legújabb elöl (évközi és lezáró jegyek is).
    public static func recentGrades(_ grades: [Grade], now: Date, days: Int = 30) -> [Grade] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return grades.filter { $0.kind != .unknown && $0.writeDate >= cutoff && $0.writeDate <= now }
            .sorted { $0.writeDate > $1.writeDate }
    }

    /// A még hátralévő helyettesítések és elmaradó órák, időrendben.
    public static func upcomingChanges(_ lessons: [Lesson], now: Date) -> [Lesson] {
        lessons.filter { $0.isChanged && $0.end > now }.sorted { $0.start < $1.start }
    }
}
