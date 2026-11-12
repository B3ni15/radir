import Foundation
import Testing
@testable import RadirKit

@Suite struct RenamingTests {
    @Test func renamesSubjectAndTeachers() throws {
        let r = Renaming(subjects: ["fizika": "Fizi"], teachers: ["Tóth László": "Laci bá", "Szabó Péter": ""])
        let l = try fixtureLessons()[1]   // fizika, Tóth László, helyettes: Szabó Péter
        let x = r.apply(l)
        #expect(x.title == "Fizi" && x.subject.id == "fizika")
        #expect(x.teacher == "Laci bá")
        #expect(x.substituteTeacher == "Szabó Péter", "üres név nem írja felül")
        #expect(r.apply(try fixtureLessons()[0]).title == "Matematika")
    }

    @Test func appliesToGradeBook() throws {
        let book = GradeBook(grades: try fixtureGrades(), classAverages: [], fetchedAt: .now)
        let renamed = Renaming(subjects: ["matek": "Matek"]).apply(book)
        #expect(renamed.subjects.first { $0.id == "matek" }?.name == "Matek")
        #expect(renamed.grades.count == book.grades.count)
    }
}
