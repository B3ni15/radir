import Foundation
import Testing
@testable import RadirKit

@Suite struct YearSummaryTests {
    func absence(_ kind: Absence.Kind, _ state: Absence.State, delay: Int = 0) -> Absence {
        Absence(id: UUID().uuidString, date: .now, kind: kind, state: state, delayMinutes: delay, justification: "",
                subject: Subject(id: "m", name: "M", categoryName: ""), teacher: "", lessonIndex: 1, lessonStart: nil, lessonEnd: nil, recorded: nil)
    }

    func book(_ gs: [Grade]) -> GradeBook { GradeBook(grades: gs, classAverages: [], fetchedAt: .now) }

    @Test func statsAndBestWorst() {
        let s = YearSummary(book: book([grade(5, subject: "a"), grade(5, subject: "a"), grade(2, subject: "b"), grade(4, subject: "b")]),
                            absences: [absence(.absence, .excused), absence(.late, .unexcused, delay: 7)])
        #expect(s.gradeCount == 4 && s.fives == 2)
        #expect(s.best?.subject.id == "a" && s.worst?.subject.id == "b" && s.worst?.average == 3)
        #expect(s.mostCommon?.grade == 5 && s.mostCommon?.count == 2)
        #expect(s.absenceCount == 1 && s.lateMinutes == 7)
    }

    @Test func personalityRulesInLegacyOrder() {
        #expect(YearSummary(book: book([grade(5), grade(5)]), absences: []).personality == .geek)
        #expect(YearSummary(book: book([grade(1), grade(1), grade(4)]), absences: []).personality == .fallible)
        #expect(YearSummary(book: book([grade(3)]), absences: []).personality == .healthy)
        let many = (0..<20).map { _ in absence(.absence, .unexcused) }
        #expect(YearSummary(book: book([grade(3)]), absences: many).personality == .quitter)
        let excused = (0..<20).map { _ in absence(.absence, .excused) }
        #expect(YearSummary(book: book([grade(3), grade(3), grade(4)]), absences: excused).personality == .average)
    }
}
