import Foundation

public struct ClassAverage: Codable, Hashable, Sendable {
    public let subjectID: String
    public let average: Double

    public init(subjectID: String, average: Double) {
        self.subjectID = subjectID
        self.average = average
    }
}

/// Egy fiók jegyei és osztályátlagai, ahogy a gyorsítótárba is kerül.
public struct GradeBook: Codable, Sendable, Equatable {
    public var grades: [Grade]
    public var classAverages: [ClassAverage]
    public var fetchedAt: Date

    public init(grades: [Grade], classAverages: [ClassAverage], fetchedAt: Date) {
        self.grades = grades
        self.classAverages = classAverages
        self.fetchedAt = fetchedAt
    }

    private static let behaviorTypes: Set = ["4,MagatartasErtek", "5,SzorgalomErtek"]

    /// Évközi jegyek, az átlagok és a grafikon alapja.
    public var midYear: [Grade] { grades.filter { $0.kind == .midYear } }

    /// Tantárgyak ábécérendben; a csak magatartás/szorgalom tantárgyak kimaradnak.
    public var subjects: [Subject] {
        var seen: [String: Subject] = [:]
        for g in grades where !g.subject.id.isEmpty && !Self.behaviorTypes.contains(g.valueTypeID) {
            seen[g.subject.id] = seen[g.subject.id] ?? g.subject
        }
        let hu = Locale(identifier: "hu_HU")
        return seen.values.sorted { $0.name.compare($1.name, locale: hu) == .orderedAscending }
    }

    /// A tantárgy évközi jegyei, legújabb elöl.
    public func grades(for subject: Subject) -> [Grade] {
        midYear.filter { $0.subject.id == subject.id }.sorted { $0.date > $1.date }
    }

    /// Félévi, év végi, negyedéves és vizsgajegyek.
    public func finals(for subject: Subject) -> [Grade] {
        grades.filter { $0.subject.id == subject.id && $0.kind != .midYear && $0.kind != .unknown }.sorted { $0.date < $1.date }
    }

    public func classAverage(for subject: Subject) -> Double? {
        classAverages.first { $0.subjectID == subject.id && $0.average > 0 }?.average
    }

    public var overallClassAverage: Double? {
        let values = classAverages.map(\.average).filter { $0 > 0 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
