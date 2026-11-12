import Foundation

public struct Subject: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let categoryName: String

    public init(id: String, name: String, categoryName: String) {
        self.id = id
        self.name = name
        self.categoryName = categoryName
    }
}

public enum GradeKind: String, Codable, Sendable {
    case midYear, firstQ, secondQ, halfYear, thirdQ, fourthQ, endYear, levelExam, unknown

    init(kreta name: String?) {
        self = switch name {
        case "evkozi_jegy_ertekeles": .midYear
        case "I_ne_jegy_ertekeles": .firstQ
        case "II_ne_jegy_ertekeles": .secondQ
        case "felevi_jegy_ertekeles": .halfYear
        case "III_ne_jegy_ertekeles": .thirdQ
        case "IV_ne_jegy_ertekeles": .fourthQ
        case "evvegi_jegy_ertekeles": .endYear
        case "osztalyozo_vizsga": .levelExam
        default: .unknown
        }
    }
}

public struct Grade: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// A jegy dátuma (`KeszitesDatuma`)
    public let date: Date
    /// Rögzítés ideje (`RogzitesDatuma`), a grafikon ezt használja, mint a legacy
    public let writeDate: Date
    /// 1–5; szöveges értékelésnél a legacy szerinti megfeleltetés, egyébként 0
    public let value: Int
    public let valueName: String
    public let shortName: String
    public let weight: Int
    public let kind: GradeKind
    public let subject: Subject
    public let topic: String
    public let mode: String
    public let teacher: String
    public let valueTypeID: String

    public init(id: String, date: Date, writeDate: Date, value: Int, valueName: String, shortName: String, weight: Int,
                kind: GradeKind, subject: Subject, topic: String, mode: String, teacher: String, valueTypeID: String) {
        self.id = id
        self.date = date
        self.writeDate = writeDate
        self.value = value
        self.valueName = valueName
        self.shortName = shortName
        self.weight = weight
        self.kind = kind
        self.subject = subject
        self.topic = topic
        self.mode = mode
        self.teacher = teacher
        self.valueTypeID = valueTypeID
    }

    /// Beleszámít-e az átlagba.
    public var isNumeric: Bool { (1...5).contains(value) && weight > 0 }

    public static func decodeKreta(_ data: Data) throws -> [Grade] {
        try JSONDecoder().decode([KretaGrade].self, from: data).map(Grade.init)
    }
}

/// `Ertekelesek` elem, ahogy a KRÉTA küldi.
struct KretaGrade: Decodable {
    struct Ref: Decodable {
        let Uid: String?
        let Nev: String?
        let Leiras: String?
    }

    struct SubjectRef: Decodable {
        let Uid: String?
        let Nev: String?
        let Kategoria: Ref?
    }

    let Uid: String?
    let KeszitesDatuma: String?
    let RogzitesDatuma: String?
    let SzamErtek: Int?
    let SzovegesErtek: String?
    let SzovegesErtekelesRovidNev: String?
    let SulySzazalekErteke: Int?
    let ErtekeloTanarNeve: String?
    let Tema: String?
    let Tipus: Ref?
    let Tantargy: SubjectRef?
    let ErtekFajta: Ref?
    let Mod: Ref?
}

private let textGrades = ["peldas": 5, "jo": 4, "valtozo": 3, "rossz": 2, "hanyag": 1]

private func meaningful(_ s: String?) -> String? {
    guard let s, s != "Na", !s.isEmpty else { return nil }
    return s
}

extension Grade {
    init(_ k: KretaGrade) {
        let name = (k.SzovegesErtek ?? "").components(separatedBy: "(")[0]
        let key = name.lowercased().folding(options: .diacriticInsensitive, locale: nil).trimmingCharacters(in: .whitespaces)
        var value = k.SzamErtek ?? 0
        var weight = k.SulySzazalekErteke ?? 0
        // legacy: a magatartás/szorgalom szöveges értéke számmá válik, de nem számít az átlagba
        if value == 0, let mapped = textGrades[key] {
            value = mapped
            weight = 0
        }
        let date = kretaDate(k.KeszitesDatuma) ?? .distantPast
        self.init(
            id: k.Uid ?? UUID().uuidString,
            date: date,
            writeDate: kretaDate(k.RogzitesDatuma) ?? date,
            value: value,
            valueName: name,
            shortName: k.SzovegesErtekelesRovidNev ?? "",
            weight: weight,
            kind: GradeKind(kreta: k.Tipus?.Nev),
            subject: Subject(id: k.Tantargy?.Uid ?? "",
                             name: (k.Tantargy?.Nev ?? "").trimmingCharacters(in: .whitespaces),
                             categoryName: meaningful(k.Tantargy?.Kategoria?.Nev) ?? ""),
            topic: k.Tema ?? "",
            mode: meaningful(k.Mod?.Leiras) ?? meaningful(k.Mod?.Nev) ?? "",
            teacher: (k.ErtekeloTanarNeve ?? "").trimmingCharacters(in: .whitespaces),
            valueTypeID: k.ErtekFajta?.Uid ?? "")
    }
}
