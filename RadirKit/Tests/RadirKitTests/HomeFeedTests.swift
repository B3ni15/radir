import Foundation
import Testing
@testable import RadirKit

@Suite struct HomeFeedTests {
    @Test func recentGradesNewestFirstWithinWindow() {
        let now = Date(timeIntervalSince1970: 40 * 86_400)
        let gs = [grade(5, day: 5), grade(4, day: 20), grade(3, day: 39), grade(2, day: 41), grade(1, day: 30, kind: .unknown)]
        #expect(HomeFeed.recentGrades(gs, now: now).map(\.value) == [3, 4])
    }

    @Test func upcomingChangesOnly() throws {
        let ls = try fixtureLessons()
        // l3 helyettesítés, l4 elmarad, 2026-11-10 10:00 után már csak az l4 vége hátravan
        #expect(HomeFeed.upcomingChanges(ls, now: budapest(2026, 11, 10, 7, 0)).map(\.id) == ["l3", "l4"])
        #expect(HomeFeed.upcomingChanges(ls, now: budapest(2026, 11, 10, 11, 0)).map(\.id) == ["l4"])
        #expect(HomeFeed.upcomingChanges(ls, now: budapest(2026, 11, 10, 12, 0)).isEmpty)
    }

    @Test func groupsByDayNewestFirst() throws {
        let ls = try fixtureLessons()   // l3, l4: 2026-11-10
        let g1 = Grade(id: "a", date: budapest(2026, 11, 9), writeDate: budapest(2026, 11, 9, 10), value: 5, valueName: "", shortName: "",
                       weight: 100, kind: .midYear, subject: Subject(id: "m", name: "M", categoryName: ""), topic: "", mode: "", teacher: "", valueTypeID: "")
        let g2 = Grade(id: "b", date: budapest(2026, 11, 10), writeDate: budapest(2026, 11, 10, 23, 30), value: 4, valueName: "", shortName: "",
                       weight: 100, kind: .midYear, subject: Subject(id: "m", name: "M", categoryName: ""), topic: "", mode: "", teacher: "", valueTypeID: "")
        let days = HomeFeed.days(grades: [g1, g2], changes: ls.filter(\.isChanged))
        #expect(days.map(\.date) == [budapest(2026, 11, 10), budapest(2026, 11, 9)])
        #expect(days[0].entries.map(\.id) == ["l-l3", "l-l4", "g-b"])
        #expect(days[1].entries.map(\.id) == ["g-a"])
    }

    @Test func mixesAllCategoriesByDay() throws {
        var src = FeedSources()
        src.absences = try Absence.decodeKreta(fixture("Mulasztasok"))         // nov. 10., 11., 12.
        src.homework = try Homework.decodeKreta(fixture("HaziFeladatok"))     // h1 rögzítve nov. 10.
        src.exams = try Exam.decodeKreta(fixture("BejelentettSzamonkeresek")) // bejelentve nov. 5.
        src.notes = try SchoolNote.decodeKreta(fixture("Feljegyzesek"))       // nov. 4.
        let days = HomeFeed.days(src)
        let nov10 = try #require(days.first { $0.date == budapest(2026, 11, 10) })
        #expect(Set(nov10.entries.map(\.id)) == ["a-a1", "h-h1"])
        #expect(days.contains { $0.date == budapest(2026, 11, 5) && $0.entries.map(\.id) == ["e-e1"] })
        #expect(days.contains { $0.date == budapest(2026, 11, 4) && $0.entries.map(\.id) == ["n-n1"] })
        #expect(days.map(\.date) == days.map(\.date).sorted(by: >))
    }
}
