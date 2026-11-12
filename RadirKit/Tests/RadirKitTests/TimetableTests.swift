import Foundation
import Testing
@testable import RadirKit

func fixtureLessons() throws -> [Lesson] {
    let url = try #require(Bundle.module.url(forResource: "OrarendElemek", withExtension: "json", subdirectory: "Fixtures"))
    return try Lesson.decodeKreta(Data(contentsOf: url))
}

func budapest(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    Calendar.school.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

@Suite struct LessonTests {
    @Test func decodesLesson() throws {
        let l = try fixtureLessons()[0]
        #expect(l.id == "l1" && l.index == 1 && l.yearIndex == 42)
        #expect(l.subject.name == "Matematika")
        #expect(l.start == budapest(2026, 11, 10, 8, 0))
        #expect(l.end == budapest(2026, 11, 10, 8, 45))
        #expect(l.room == "201")
        #expect(l.teacher == "Nagy Katalin" && l.substituteTeacher == nil)
        #expect(l.topic == "Másodfokú egyenletek")
        #expect(l.examID == "exam1")
        #expect(!l.isCancelled && !l.wasAbsent && !l.isChanged)
    }

    @Test func substitutionAndCancellation() throws {
        let ls = try fixtureLessons()
        #expect(ls[1].substituteTeacher == "Szabó Péter" && ls[1].isChanged)
        #expect(ls[2].isCancelled && ls[2].wasAbsent && ls[2].isChanged)
    }

    @Test func roomCleaning() throws {
        let ls = try fixtureLessons()
        #expect(ls[1].room == "Fizika előadó")
        #expect(ls[5].room == "Tornaterem", "a szó belsejében lévő „terem” marad")
        #expect(ls[3].index == nil)
    }
}

@Suite struct SchoolWeekTests {
    @Test func weekContainingDate() {
        let w = SchoolWeek(containing: budapest(2026, 11, 12, 15))
        #expect(w.start == budapest(2026, 11, 9))
        #expect(w.end == budapest(2026, 11, 15))
        #expect(w.days.count == 5 && w.days.last == budapest(2026, 11, 13))
        #expect(w.next.start == budapest(2026, 11, 16))
        #expect(w.previous.start == budapest(2026, 11, 2))
    }

    @Test func schoolYearStartSkipsWeekend() {
        #expect(SchoolWeek.schoolYearStart(for: budapest(2026, 11, 1)) == budapest(2026, 9, 1))
        // 2024. szeptember 1. vasárnap → hétfő
        #expect(SchoolWeek.schoolYearStart(for: budapest(2024, 10, 1)) == budapest(2024, 9, 2))
        // tavasszal az előző év szeptembere
        #expect(SchoolWeek.schoolYearStart(for: budapest(2027, 3, 1)) == budapest(2026, 9, 1))
    }

    @Test func weekNumberFromSchoolYearStart() {
        #expect(SchoolWeek(containing: budapest(2026, 9, 2)).number == 1)
        #expect(SchoolWeek(containing: budapest(2026, 9, 7)).number == 2)
        #expect(SchoolWeek(containing: budapest(2026, 11, 12)).number == 11)
    }
}

@Suite struct TimetableDaysTests {
    @Test func groupsByDayAndFillsGaps() throws {
        let days = Timetable.days(try fixtureLessons())
        #expect(days.map(\.date) == [budapest(2026, 11, 10), budapest(2026, 11, 12)])
        let tue = days[0].entries
        // esemény elöl, majd 1., üres 2., 3., 4., végül az óraszám nélküli
        #expect(tue.map(\.label) == ["event", "l1", "free2", "l3", "l4", "plus"])
        #expect(days[1].entries.map(\.label) == ["l5"])
    }

    @Test func breaksBetweenEveryLesson() throws {
        let bp = { (h: Int, m: Int) in budapest(2026, 11, 12, h, m) }
        func lesson(_ id: String, _ i: Int?, _ sh: Int, _ sm: Int, cancelled: Bool = false) -> Lesson {
            Lesson(id: id, date: budapest(2026, 11, 12), start: bp(sh, sm), end: bp(sh, sm).addingTimeInterval(45 * 60),
                   subject: Subject(id: id, name: id, categoryName: ""), index: i, yearIndex: nil, name: id, teacher: "",
                   substituteTeacher: nil, room: "", topic: "", groupName: "", isCancelled: cancelled, wasAbsent: false,
                   homeworkID: nil, examID: nil, isOnline: false)
        }
        // 2. 8:55–9:40 | 15 | 3. 9:55–10:40 | 10 | 4. 10:50–11:35 | 5. hiányzik | 6. 12:45 (elmarad) | 7. 13:30 (0 perc)
        let ls = [lesson("b", 2, 8, 55), lesson("c", 3, 9, 55), lesson("d", 4, 10, 50),
                  lesson("f", 6, 12, 45, cancelled: true), lesson("g", 7, 13, 30)]
        let items = Timetable.days(ls)[0].items
        #expect(items.map(\.label) == ["b", "pause15", "c", "pause10", "d", "free5", "f", "g"])
        if case .pause(let from, let to) = items[3] {
            #expect(from == bp(10, 40) && to == bp(10, 50))
        } else { Issue.record("nem szünet") }
    }

    @Test func emptyInput() {
        #expect(Timetable.days([]).isEmpty)
    }
}

extension TimetableItem {
    var label: String {
        switch self {
        case .entry(let e): e.label
        case .pause(let from, let to): "pause\(Int(to.timeIntervalSince(from) / 60))"
        }
    }
}

extension TimetableEntry {
    var label: String {
        switch self {
        case .lesson(let l): l.id
        case .free(let i, _): "free\(i)"
        }
    }
}
