import Foundation

/// Tantárgyak és tanárok saját elnevezése (a legacy átnevezés funkciója). Csak a megjelenítést érinti.
public struct Renaming: Codable, Equatable, Sendable {
    /// tantárgy id → név
    public var subjects: [String: String] = [:]
    /// eredeti tanárnév → név
    public var teachers: [String: String] = [:]

    public init(subjects: [String: String] = [:], teachers: [String: String] = [:]) {
        self.subjects = subjects
        self.teachers = teachers
    }

    public var isEmpty: Bool { subjects.isEmpty && teachers.isEmpty }

    func subject(_ s: Subject) -> Subject {
        guard let n = subjects[s.id], !n.isEmpty else { return s }
        var r = s
        r.name = n
        return r
    }

    func teacher(_ t: String) -> String { teachers[t].flatMap { $0.isEmpty ? nil : $0 } ?? t }

    public func apply(_ g: Grade) -> Grade { var g = g; g.subject = subject(g.subject); g.teacher = teacher(g.teacher); return g }
    public func apply(_ b: GradeBook) -> GradeBook { var b = b; b.grades = b.grades.map(apply); return b }
    public func apply(_ l: Lesson) -> Lesson {
        var l = l
        l.subject = subject(l.subject)
        l.teacher = teacher(l.teacher)
        l.substituteTeacher = l.substituteTeacher.map(teacher)
        return l
    }
    public func apply(_ a: Absence) -> Absence { var a = a; a.subject = subject(a.subject); a.teacher = teacher(a.teacher); return a }
    public func apply(_ h: Homework) -> Homework { var h = h; h.subject = subject(h.subject); h.teacher = teacher(h.teacher); return h }
    public func apply(_ e: Exam) -> Exam { var e = e; e.subject = subject(e.subject); e.teacher = teacher(e.teacher); return e }
}
