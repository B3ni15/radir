import Foundation

public struct Lesson: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// A nap (budapesti éjfél)
    public let date: Date
    public let start: Date
    public let end: Date
    public let subject: Subject
    /// Óraszám; nil, ha a KRÉTA nem ad (szakkör, esemény)
    public let index: Int?
    /// Hányadik óra az évben ebből a tantárgyból
    public let yearIndex: Int?
    public let name: String
    public let teacher: String
    public let substituteTeacher: String?
    public let room: String
    public let topic: String
    public let groupName: String
    public let isCancelled: Bool
    public let wasAbsent: Bool
    public let homeworkID: String?
    public let examID: String?
    public let isOnline: Bool

    public init(id: String, date: Date, start: Date, end: Date, subject: Subject, index: Int?, yearIndex: Int?, name: String,
                teacher: String, substituteTeacher: String?, room: String, topic: String, groupName: String,
                isCancelled: Bool, wasAbsent: Bool, homeworkID: String?, examID: String?, isOnline: Bool) {
        self.id = id; self.date = date; self.start = start; self.end = end; self.subject = subject; self.index = index
        self.yearIndex = yearIndex; self.name = name; self.teacher = teacher; self.substituteTeacher = substituteTeacher
        self.room = room; self.topic = topic; self.groupName = groupName; self.isCancelled = isCancelled
        self.wasAbsent = wasAbsent; self.homeworkID = homeworkID; self.examID = examID; self.isOnline = isOnline
    }

    public var isSubstitution: Bool { substituteTeacher != nil }
    /// A legacy `isChanged`: elmaradt vagy helyettesített
    public var isChanged: Bool { isCancelled || isSubstitution }
    /// Esemény (tantárgy nélkül), pl. fogadóóra
    public var isEvent: Bool { subject.id.isEmpty }
    public var title: String { subject.name.isEmpty ? name : subject.name }

    public static func decodeKreta(_ data: Data) throws -> [Lesson] {
        try JSONDecoder().decode([KretaLesson].self, from: data).map(Lesson.init)
    }
}

struct KretaLesson: Decodable {
    struct Ref: Decodable { let Uid: String?; let Nev: String? }
    struct SubjectRef: Decodable { let Uid: String?; let Nev: String?; let Kategoria: Ref? }

    let Uid: String?
    let Datum: String?
    let KezdetIdopont: String?
    let VegIdopont: String?
    let Oraszam: Int?
    let OraEvesSorszama: Int?
    let Nev: String?
    let Tema: String?
    let Tantargy: SubjectRef?
    let TanarNeve: String?
    let HelyettesTanarNeve: String?
    let TeremNeve: String?
    let OsztalyCsoport: Ref?
    let Allapot: Ref?
    let TanuloJelenlet: Ref?
    let HaziFeladatUid: String?
    let BejelentettSzamonkeresUid: String?
    let IsDigitalisOra: Bool?
}

/// „201_terem” → „201”. Csak az önálló „terem” szó tűnik el, a „Tornaterem” marad.
func cleanRoom(_ raw: String?) -> String {
    let spaced = (raw ?? "").replacingOccurrences(of: "_", with: " ")
    let removed = spaced.replacingOccurrences(of: #"(?i)\bterem\b"#, with: "", options: .regularExpression)
    return removed.split(separator: " ").joined(separator: " ")
}

private func nonEmpty(_ s: String?) -> String? {
    let t = s?.trimmingCharacters(in: .whitespaces) ?? ""
    return t.isEmpty ? nil : t
}

extension Lesson {
    init(_ k: KretaLesson) {
        let start = kretaDate(k.KezdetIdopont) ?? .distantPast
        let date = kretaDate(k.Datum).map { Calendar.school.startOfDay(for: $0) } ?? Calendar.school.startOfDay(for: start)
        self.init(
            id: k.Uid ?? UUID().uuidString, date: date, start: start, end: kretaDate(k.VegIdopont) ?? start,
            subject: Subject(id: k.Tantargy?.Uid ?? "", name: (k.Tantargy?.Nev ?? "").trimmingCharacters(in: .whitespaces),
                             categoryName: k.Tantargy?.Kategoria?.Nev ?? ""),
            index: k.Oraszam, yearIndex: k.OraEvesSorszama, name: k.Nev ?? "",
            teacher: (k.TanarNeve ?? "").trimmingCharacters(in: .whitespaces),
            substituteTeacher: nonEmpty(k.HelyettesTanarNeve), room: cleanRoom(k.TeremNeve), topic: k.Tema ?? "",
            groupName: k.OsztalyCsoport?.Nev ?? "", isCancelled: k.Allapot?.Nev == "Elmaradt",
            wasAbsent: k.TanuloJelenlet?.Nev == "Hianyzas", homeworkID: nonEmpty(k.HaziFeladatUid),
            examID: nonEmpty(k.BejelentettSzamonkeresUid), isOnline: k.IsDigitalisOra ?? false)
    }
}
