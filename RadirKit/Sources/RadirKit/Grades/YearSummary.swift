import Foundation

/// Év végi összefoglaló (a legacy „summary” képernyőinek adatai) és a „személyiség” a legacy szabályai szerint.
public struct YearSummary: Sendable {
    public enum Personality: String, CaseIterable, Sendable {
        case geek, fallible, healthy, quitter, late, sick, acceptable, average, diligent, npc
    }

    public let gradeCount: Int
    public let average: Double?
    public let best: (subject: Subject, average: Double)?
    public let worst: (subject: Subject, average: Double)?
    /// A leggyakoribb jegy és a darabszáma
    public let mostCommon: (grade: Int, count: Int)?
    public let fives: Int
    public let absenceCount: Int
    public let unexcused: Int
    public let lateMinutes: Int
    public let personality: Personality
    /// A bizonyítvány: tantárgyanként az év végi jegy, ábécérendben
    public let reportCard: [(subject: Subject, grade: Int)]
    public var reportAverage: Double? {
        reportCard.isEmpty ? nil : Double(reportCard.map(\.grade).reduce(0, +)) / Double(reportCard.count)
    }

    /// Csak a bizonyítványosztás után érhető el: amikor már van év végi jegy.
    public static func isAvailable(_ book: GradeBook?) -> Bool {
        book?.grades.contains { $0.kind == .endYear && $0.value > 0 } ?? false
    }

    public init(book: GradeBook, absences: [Absence]) {
        let grades = book.midYear.filter(\.isNumeric)
        gradeCount = grades.count
        average = Averages.weighted(grades)
        let bySubject = book.subjects.compactMap { s in Averages.weighted(book.grades(for: s)).map { (subject: s, average: $0) } }
        best = bySubject.max { $0.average < $1.average }
        worst = bySubject.min { $0.average < $1.average }
        let dist = Averages.distribution(grades)
        // egyenlőségnél a jobb jegy nyer
        mostCommon = dist.filter { $0.value > 0 }.max { ($0.value, $0.key) < ($1.value, $1.key) }.map { (grade: $0.key, count: $0.value) }
        fives = dist[5] ?? 0
        let finals = Dictionary(book.grades.filter { $0.kind == .endYear && $0.value > 0 }.map { ($0.subject.id, $0) },
                                uniquingKeysWith: { $0.date > $1.date ? $0 : $1 })
        reportCard = book.subjects.compactMap { s in finals[s.id].map { (subject: s, grade: $0.value) } }
        let missed = absences.filter { $0.kind == .absence }
        absenceCount = missed.count
        unexcused = missed.filter { $0.state == .unexcused }.count
        lateMinutes = absences.filter { $0.kind == .late }.reduce(0) { $0 + $1.delayMinutes }

        // a legacy `getPersonality` sorrendje
        let subjectAvg = bySubject.isEmpty ? 0 : bySubject.map(\.average).reduce(0, +) / Double(bySubject.count)
        let classWork = grades.filter { $0.mode.lowercased().contains("órai munka") }.count
        personality = if subjectAvg > 4.7 { .geek }
            else if mostCommon?.grade == 1 && (mostCommon?.count ?? 0) > 1 { .fallible }
            else if absenceCount <= 12 { .healthy }
            else if unexcused >= 8 { .quitter }
            else if lateMinutes > 50 { .late }
            else if absenceCount >= 120 { .sick }
            else if mostCommon?.grade == 2 { .acceptable }
            else if mostCommon?.grade == 3 { .average }
            else if classWork >= 5 { .diligent }
            else { .npc }
    }
}
