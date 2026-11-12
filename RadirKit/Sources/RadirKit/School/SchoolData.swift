import Foundation

struct KretaRef: Decodable {
    let Uid: String?
    let Nev: String?
    let Leiras: String?
}

private func trimmed(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
private func kretaSubject(_ r: KretaRef?) -> Subject { Subject(id: r?.Uid ?? "", name: trimmed(r?.Nev), categoryName: "") }
private func day(_ s: String?) -> Date? { kretaDate(s).map { Calendar.school.startOfDay(for: $0) } }

// MARK: - Hiányzás

public struct Absence: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case absence, late }
    public enum State: String, Codable, Sendable { case excused, unexcused, pending }

    public let id: String
    public let date: Date
    public let kind: Kind
    public let state: State
    public let delayMinutes: Int
    public let justification: String
    public let subject: Subject
    public let teacher: String
    public let lessonIndex: Int?
    public let lessonStart: Date?
    public let lessonEnd: Date?
    public let recorded: Date?

    public init(id: String, date: Date, kind: Kind, state: State, delayMinutes: Int, justification: String,
                subject: Subject, teacher: String, lessonIndex: Int?, lessonStart: Date?, lessonEnd: Date?, recorded: Date?) {
        self.id = id; self.date = date; self.kind = kind; self.state = state; self.delayMinutes = delayMinutes
        self.justification = justification; self.subject = subject; self.teacher = teacher; self.lessonIndex = lessonIndex
        self.lessonStart = lessonStart; self.lessonEnd = lessonEnd; self.recorded = recorded
    }

    struct DTO: Decodable {
        struct Lesson: Decodable { let KezdoDatum: String?; let VegDatum: String?; let Oraszam: Int? }
        let Uid: String?; let Datum: String?; let KeszitesDatuma: String?; let KesesPercben: Int?
        let IgazolasAllapota: String?; let IgazolasTipusa: KretaRef?; let Tipus: KretaRef?
        let Tantargy: KretaRef?; let RogzitoTanarNeve: String?; let Ora: Lesson?
    }

    public static func decodeKreta(_ data: Data) throws -> [Absence] {
        try JSONDecoder().decode([DTO].self, from: data).map { d in
            Absence(id: d.Uid ?? UUID().uuidString, date: day(d.Datum) ?? .distantPast,
                    kind: d.Tipus?.Nev == "keses" ? .late : .absence,
                    state: d.IgazolasAllapota == "Igazolt" ? .excused : d.IgazolasAllapota == "Igazolando" ? .pending : .unexcused,
                    delayMinutes: d.KesesPercben ?? 0,
                    justification: trimmed(d.IgazolasTipusa?.Leiras ?? d.IgazolasTipusa?.Nev),
                    subject: kretaSubject(d.Tantargy), teacher: trimmed(d.RogzitoTanarNeve), lessonIndex: d.Ora?.Oraszam,
                    lessonStart: kretaDate(d.Ora?.KezdoDatum), lessonEnd: kretaDate(d.Ora?.VegDatum),
                    recorded: kretaDate(d.KeszitesDatuma))
        }
    }
}

public struct AbsenceSummary: Sendable {
    public struct BySubject: Identifiable, Sendable {
        public let subject: Subject
        public let absences: Int
        public let late: Int
        public let items: [Absence]
        public var id: String { subject.id }
    }

    public let excused: Int
    public let unexcused: Int
    public let pending: Int
    public let lateCount: Int
    public let lateMinutes: Int
    /// A legtöbb hiányzás elöl.
    public let bySubject: [BySubject]

    public init(_ items: [Absence]) {
        let abs = items.filter { $0.kind == .absence }
        excused = abs.filter { $0.state == .excused }.count
        unexcused = abs.filter { $0.state == .unexcused }.count
        pending = abs.filter { $0.state == .pending }.count
        let late = items.filter { $0.kind == .late }
        lateCount = late.count
        lateMinutes = late.reduce(0) { $0 + $1.delayMinutes }
        let hu = Locale(identifier: "hu_HU")
        bySubject = Dictionary(grouping: items, by: \.subject.id).values.map { group in
            BySubject(subject: group[0].subject, absences: group.filter { $0.kind == .absence }.count,
                      late: group.filter { $0.kind == .late }.count, items: group.sorted { $0.date > $1.date })
        }
        .sorted { a, b in
            a.absences != b.absences ? a.absences > b.absences : a.subject.name.compare(b.subject.name, locale: hu) == .orderedAscending
        }
    }
}

// MARK: - Házi feladat

public struct HomeworkAttachment: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct Homework: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let subject: Subject
    public let teacher: String
    /// HTML, ahogy a KRÉTA adja
    public let text: String
    public let assigned: Date?
    public let recorded: Date?
    /// A nap, amelyikre kell
    public let deadline: Date
    public let byTeacher: Bool
    public let attachments: [HomeworkAttachment]

    public init(id: String, subject: Subject, teacher: String, text: String, assigned: Date?, recorded: Date?,
                deadline: Date, byTeacher: Bool, attachments: [HomeworkAttachment]) {
        self.id = id; self.subject = subject; self.teacher = teacher; self.text = text; self.assigned = assigned
        self.recorded = recorded; self.deadline = deadline; self.byTeacher = byTeacher; self.attachments = attachments
    }

    /// A lista néha szöveg nélkül jön: ilyenkor a részleteket külön kell lekérni.
    public var needsDetails: Bool { text.isEmpty }
    public var plainText: String { HTMLText.plain(text) }

    struct DTO: Decodable {
        struct Attachment: Decodable { let Uid: String?; let Nev: String? }
        let Uid: String?; let RogzitesIdopontja: String?; let FeladasDatuma: String?; let HataridoDatuma: String?
        let IsTanarRogzitette: Bool?; let RogzitoTanarNeve: String?; let Szoveg: String?; let Tantargy: KretaRef?
        let Csatolmanyok: [Attachment]?
    }

    static func from(_ d: DTO) -> Homework {
        Homework(id: d.Uid ?? UUID().uuidString, subject: kretaSubject(d.Tantargy), teacher: trimmed(d.RogzitoTanarNeve),
                 text: trimmed(d.Szoveg), assigned: day(d.FeladasDatuma), recorded: kretaDate(d.RogzitesIdopontja),
                 deadline: day(d.HataridoDatuma) ?? .distantPast, byTeacher: d.IsTanarRogzitette ?? true,
                 attachments: (d.Csatolmanyok ?? []).map { HomeworkAttachment(id: $0.Uid ?? "", name: $0.Nev ?? "") })
    }

    public static func decodeKreta(_ data: Data) throws -> [Homework] {
        try JSONDecoder().decode([DTO].self, from: data).map(from)
    }
}

/// A KRÉTA HTML szövegeiből olvasható szöveg.
public enum HTMLText {
    public static func plain(_ html: String) -> String {
        var s = html.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</li>|</div>"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (k, v) in ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"] {
            s = s.replacingOccurrences(of: k, with: v)
        }
        let lines = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - Számonkérés

public struct Exam: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// A számonkérés napja
    public let date: Date
    public let announced: Date?
    public let subject: Subject
    public let topic: String
    public let mode: String
    public let teacher: String
    public let lessonIndex: Int?

    public init(id: String, date: Date, announced: Date?, subject: Subject, topic: String, mode: String, teacher: String, lessonIndex: Int?) {
        self.id = id; self.date = date; self.announced = announced; self.subject = subject; self.topic = topic
        self.mode = mode; self.teacher = teacher; self.lessonIndex = lessonIndex
    }

    struct DTO: Decodable {
        let Uid: String?; let BejelentesDatuma: String?; let Datum: String?; let OrarendiOraOraszama: Int?
        let Temaja: String?; let Modja: KretaRef?; let Tantargy: KretaRef?; let RogzitoTanarNeve: String?
    }

    public static func decodeKreta(_ data: Data) throws -> [Exam] {
        try JSONDecoder().decode([DTO].self, from: data).map { d in
            Exam(id: d.Uid ?? UUID().uuidString, date: day(d.Datum) ?? .distantPast, announced: kretaDate(d.BejelentesDatuma),
                 subject: kretaSubject(d.Tantargy), topic: trimmed(d.Temaja), mode: trimmed(d.Modja?.Leiras ?? d.Modja?.Nev),
                 teacher: trimmed(d.RogzitoTanarNeve), lessonIndex: d.OrarendiOraOraszama)
        }
    }
}

// MARK: - Feljegyzés (beírás)

public struct SchoolNote: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let content: String
    public let kind: String
    public let teacher: String
    public let date: Date
    public let recorded: Date?

    public init(id: String, title: String, content: String, kind: String, teacher: String, date: Date, recorded: Date?) {
        self.id = id; self.title = title; self.content = content; self.kind = kind; self.teacher = teacher
        self.date = date; self.recorded = recorded
    }

    struct DTO: Decodable {
        let Uid: String?; let Cim: String?; let Datum: String?; let KeszitesDatuma: String?
        let KeszitoTanarNeve: String?; let Tartalom: String?; let Tipus: KretaRef?
    }

    public static func decodeKreta(_ data: Data) throws -> [SchoolNote] {
        try JSONDecoder().decode([DTO].self, from: data).map { d in
            SchoolNote(id: d.Uid ?? UUID().uuidString, title: trimmed(d.Cim),
                       content: HTMLText.plain((d.Tartalom ?? "").replacingOccurrences(of: "\r", with: "")),
                       kind: trimmed(d.Tipus?.Leiras ?? d.Tipus?.Nev), teacher: trimmed(d.KeszitoTanarNeve),
                       date: day(d.Datum) ?? .distantPast, recorded: kretaDate(d.KeszitesDatuma))
        }
    }
}

// MARK: - Letöltés

public struct SchoolDataService: Sendable {
    public init() {}

    private func base(_ institute: String) -> URL { Kreta.base(institute).appending(path: "ellenorzo/V3/Sajat") }

    public func absences(session: KretaSession, instituteCode: String) async throws -> [Absence] {
        try Absence.decodeKreta(try await session.data(for: base(instituteCode).appending(path: "Mulasztasok")))
    }

    public func exams(session: KretaSession, instituteCode: String) async throws -> [Exam] {
        try Exam.decodeKreta(try await session.data(for: base(instituteCode).appending(path: "BejelentettSzamonkeresek")))
    }

    public func notes(session: KretaSession, instituteCode: String) async throws -> [SchoolNote] {
        try SchoolNote.decodeKreta(try await session.data(for: base(instituteCode).appending(path: "Feljegyzesek")))
    }

    /// `from` naptól; ahol a listában nincs szöveg, ott tételenként lekéri a részleteket (mint a legacy).
    public func homework(session: KretaSession, instituteCode: String, from: Date) async throws -> [Homework] {
        let day = from.formatted(Date.ISO8601FormatStyle(timeZone: Calendar.school.timeZone).year().month().day())
        let url = base(instituteCode).appending(path: "HaziFeladatok").appending(queryItems: [URLQueryItem(name: "datumTol", value: day)])
        var items = try Homework.decodeKreta(try await session.data(for: url))
        for (i, h) in items.enumerated() where h.needsDetails {
            let detailURL = base(instituteCode).appending(path: "HaziFeladatok/\(h.id)")
            if let d = try? await session.get(Homework.DTO.self, from: detailURL) { items[i] = Homework.from(d) }
        }
        return items
    }
}
