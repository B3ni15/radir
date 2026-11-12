import Foundation

/// Determinisztikus véletlen (SplitMix64): ugyanarra a magra ugyanazt adja, így a demó egy napon belül stabil.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Véletlenszerűen generált demó adatok, a valódi fiókoktól teljesen függetlenül. Naponta változnak.
extension Demo {
    struct DemoSubject {
        let id, name, teacher: String
        let topics: [String]
        let rooms: [String]
    }

    static let subjects: [DemoSubject] = [
        .init(id: "matek", name: "Matematika", teacher: "Nagy Katalin", topics: ["Halmazok", "Függvények", "Egyenletek", "Szöveges feladatok", "Geometria"], rooms: ["201"]),
        .init(id: "magyarnyelv", name: "Magyar nyelv", teacher: "Kovács Mária", topics: ["Helyesírás", "Szófajok", "Mondatelemzés"], rooms: ["105"]),
        .init(id: "irodalom", name: "Irodalom", teacher: "Kovács Mária", topics: ["Antikvitás", "Biblia", "Memoriter", "Házi olvasmány"], rooms: ["105"]),
        .init(id: "tori", name: "Történelem", teacher: "Szabó Péter", topics: ["Ókori Kelet", "Görögök", "Róma", "Középkor"], rooms: ["204"]),
        .init(id: "angol", name: "Angol nyelv", teacher: "Varga Erzsébet", topics: ["Unit 3", "Vocabulary", "Present Perfect", "Listening"], rooms: ["Nyelvi 2"]),
        .init(id: "fizika", name: "Fizika", teacher: "Tóth László", topics: ["Mozgások", "Newton törvényei", "Munka és energia"], rooms: ["Fizika előadó"]),
        .init(id: "bio", name: "Biológia", teacher: "Fekete Gábor", topics: ["Sejtek", "Növények", "Kiselőadás"], rooms: ["Labor"]),
        .init(id: "kemia", name: "Kémia", teacher: "Tóth László", topics: ["Atomszerkezet", "Periódusos rendszer", "Kötések"], rooms: ["Labor"]),
        .init(id: "info", name: "Informatika", teacher: "Fekete Gábor", topics: ["Táblázatkezelés", "Algoritmusok", "Projekt"], rooms: ["Gépterem 1"]),
        .init(id: "tesi", name: "Testnevelés", teacher: "Szabó Péter", topics: ["Futás", "Kosárlabda", "Torna"], rooms: ["Tornaterem"]),
        .init(id: "foci", name: "Földrajz", teacher: "Kiss Andrea", topics: ["Kőzetek", "Éghajlat", "Európa"], rooms: ["207"]),
    ]

    // a kategória az eredeti név, mint a KRÉTA-ban: átnevezés után is erből jön az ikon
    static func subject(_ s: DemoSubject) -> Subject { Subject(id: s.id, name: s.name, categoryName: s.name) }

    static func seed(for date: Date, salt: UInt64 = 0) -> SeededRandom {
        SeededRandom(seed: UInt64(max(0, Int(date.timeIntervalSince1970 / 86_400))) &* 31 &+ salt)
    }

    /// `days` nappal `now` után (negatív: előtte), hétvégénél a múltban péntekre, a jövőben hétfőre tolva.
    static func schoolDay(_ now: Date, _ days: Int) -> Date {
        let cal = Calendar.school
        var d = cal.startOfDay(for: cal.date(byAdding: .day, value: days, to: now)!)
        while cal.isDateInWeekend(d) { d = cal.date(byAdding: .day, value: days < 0 ? -1 : 1, to: d)! }
        return d
    }

    private static let valueNames = [1: "Elégtelen", 2: "Elégséges", 3: "Közepes", 4: "Jó", 5: "Jeles"]

    /// Tantárgyanként 3–8 jegy az elmúlt 70 napban, inkább jó jegyek.
    public static func gradeBook(now: Date = .now) -> GradeBook {
        var rng = seed(for: now, salt: 1)
        let weights = [1, 2, 4, 7, 7]  // 1-es … 5-ös gyakorisága
        func value() -> Int {
            var r = Int.random(in: 0..<weights.reduce(0, +), using: &rng)
            for (i, w) in weights.enumerated() { if r < w { return i + 1 }; r -= w }
            return 5
        }
        var grades: [Grade] = []
        var classAverages: [ClassAverage] = []
        for s in subjects {
            for i in 0..<Int.random(in: 3...8, using: &rng) {
                let v = value(), heavy = Int.random(in: 0..<5, using: &rng) == 0
                let date = schoolDay(now, -Int.random(in: 0...70, using: &rng))
                let written = min(date.addingTimeInterval(Double(Int.random(in: 8...15, using: &rng)) * 3600), now)
                grades.append(Grade(id: "demo-\(s.id)-\(i)", date: date, writeDate: written, value: v, valueName: valueNames[v]!,
                                    shortName: String(v), weight: heavy ? 200 : 100, kind: .midYear, subject: subject(s),
                                    topic: heavy ? "Témazáró dolgozat" : s.topics.randomElement(using: &rng)!,
                                    mode: heavy ? "Írásbeli témazáró dolgozat" : ["Írásbeli röpdolgozat", "Szóbeli felelet", "Órai munka"].randomElement(using: &rng)!,
                                    teacher: s.teacher, valueTypeID: "1,Osztalyzat"))
            }
            classAverages.append(ClassAverage(subjectID: s.id, average: Double(Int.random(in: 300...460, using: &rng)) / 100))
        }
        return GradeBook(grades: grades, classAverages: classAverages, fetchedAt: now)
    }

    private static let bells = [(8, 0), (8, 55), (9, 50), (10, 50), (11, 45), (12, 40), (13, 35)]

    /// Hetente más órarend; minden héten van legalább egy helyettesítés és egy elmaradó óra.
    public static func lessons(for week: SchoolWeek) -> [Lesson] {
        var rng = seed(for: week.start, salt: 2)
        let cal = Calendar.school
        var out: [Lesson] = []
        let substitutionDay = Int.random(in: 0..<5, using: &rng), cancelDay = Int.random(in: 0..<5, using: &rng)
        for (d, day) in week.days.enumerated() {
            let count = Int.random(in: 5...7, using: &rng)
            let first = Int.random(in: 0...1, using: &rng)
            for i in first..<min(first + count, bells.count) {
                let s = subjects.randomElement(using: &rng)!
                let start = cal.date(bySettingHour: bells[i].0, minute: bells[i].1, second: 0, of: day)!
                let sub = d == substitutionDay && i == first + 1 ? subjects.filter { $0.teacher != s.teacher }.randomElement(using: &rng)!.teacher : nil
                out.append(Lesson(
                    id: "demo-\(week.number)-\(d)-\(i)", date: day, start: start, end: start.addingTimeInterval(45 * 60),
                    subject: subject(s), index: i + 1, yearIndex: week.number * 3 + i, name: s.name, teacher: s.teacher,
                    substituteTeacher: sub, room: s.rooms[0], topic: s.topics.randomElement(using: &rng)!, groupName: "10.A",
                    isCancelled: d == cancelDay && i == first + count - 2, wasAbsent: false, homeworkID: nil, examID: nil, isOnline: false))
            }
        }
        return out
    }

    public static func absences(now: Date = .now) -> [Absence] {
        var rng = seed(for: now, salt: 3)
        return (0..<Int.random(in: 4...12, using: &rng)).map { i in
            let s = subjects.randomElement(using: &rng)!
            let day = schoolDay(now, -Int.random(in: 1...60, using: &rng))
            let late = Int.random(in: 0..<4, using: &rng) == 0
            let state: Absence.State = [.excused, .excused, .excused, .pending, .unexcused].randomElement(using: &rng)!
            let index = Int.random(in: 1...6, using: &rng)
            let start = Calendar.school.date(bySettingHour: bells[index - 1].0, minute: bells[index - 1].1, second: 0, of: day)!
            return Absence(id: "demo-abs-\(i)", date: day, kind: late ? .late : .absence, state: late ? .unexcused : state,
                           delayMinutes: late ? Int.random(in: 2...15, using: &rng) : 0,
                           justification: state == .excused && !late ? ["Orvosi igazolás", "Szülői igazolás"].randomElement(using: &rng)! : "",
                           subject: subject(s), teacher: s.teacher, lessonIndex: index, lessonStart: start,
                           lessonEnd: start.addingTimeInterval(45 * 60), recorded: start.addingTimeInterval(3600))
        }
    }

    public static func homework(now: Date = .now) -> [Homework] {
        var rng = seed(for: now, salt: 4)
        let tasks = ["Tankönyv 45. oldal 1–3. feladat", "Olvasd el a következő fejezetet!", "Munkafüzet 12. oldal",
                     "Készíts vázlatot a leckéből.", "Tanuld meg a szavakat a 3. leckéből.", "Oldd meg a kiadott feladatlapot."]
        return (0..<Int.random(in: 3...6, using: &rng)).map { i in
            let s = subjects.randomElement(using: &rng)!
            let deadline = schoolDay(now, Int.random(in: -3...7, using: &rng))
            return Homework(id: "demo-hw-\(i)", subject: subject(s), teacher: s.teacher, text: tasks.randomElement(using: &rng)!,
                            assigned: deadline.addingTimeInterval(-2 * 86_400), recorded: deadline.addingTimeInterval(-2 * 86_400 + 12 * 3600),
                            deadline: deadline, byTeacher: true, attachments: [])
        }
    }

    public static func exams(now: Date = .now) -> [Exam] {
        var rng = seed(for: now, salt: 5)
        return (0..<Int.random(in: 2...4, using: &rng)).map { i in
            let s = subjects.randomElement(using: &rng)!
            let day = schoolDay(now, Int.random(in: 1...14, using: &rng))
            return Exam(id: "demo-exam-\(i)", date: day, announced: now.addingTimeInterval(-Double(Int.random(in: 1...5, using: &rng)) * 86_400),
                        subject: subject(s), topic: s.topics.randomElement(using: &rng)!,
                        mode: ["Írásbeli témazáró dolgozat", "Írásbeli röpdolgozat", "Szóbeli felelet"].randomElement(using: &rng)!,
                        teacher: s.teacher, lessonIndex: Int.random(in: 1...6, using: &rng))
        }
    }

    public static func schoolNotes(now: Date = .now) -> [SchoolNote] {
        var rng = seed(for: now, salt: 6)
        let samples = [("Dicséret", "Dicséret", "Kiváló szereplés a tanulmányi versenyen."),
                       ("Szaktanári figyelmeztetés", "Figyelmeztetés", "A házi feladat ismételten hiányzott."),
                       ("Osztálykirándulás", "Értesítés", "A kirándulás péntek 8:00-kor indul a főbejárattól.")]
        return (0..<Int.random(in: 1...3, using: &rng)).map { i in
            let (title, kind, content) = samples[i]
            let day = schoolDay(now, -Int.random(in: 0...20, using: &rng))
            return SchoolNote(id: "demo-note-\(i)", title: title, content: content, kind: kind,
                              teacher: subjects.randomElement(using: &rng)!.teacher, date: day, recorded: day.addingTimeInterval(10 * 3600))
        }
    }
}

extension Demo {
    public static func messages(_ box: MailBox, now: Date = .now) -> [KretaMessage] {
        var rng = seed(for: now, salt: 7)
        let inbox = [("Holnapi dolgozat", "Kedves Diákok!\nHolnap az első órán dolgozatot írunk a függvényekből."),
                     ("Szülői értekezlet", "Tisztelt Szülők!\nA szülői értekezlet csütörtökön 17:00-kor lesz a 105-ös teremben."),
                     ("Kirándulás", "A kiránduláshoz szükséges nyilatkozatot péntekig kérem leadni."),
                     ("Versenyfelhívás", "Jelentkezni lehet a tanulmányi versenyre az osztályfőnöknél.")]
        switch box {
        case .inbox:
            return inbox.enumerated().map { i, m in
                let s = subjects.randomElement(using: &rng)!
                return KretaMessage(id: 1000 + i, box: .inbox, isRead: i > 0, date: now.addingTimeInterval(-Double(i * 2 + 1) * 86_400 + 3600),
                                    sender: i == 1 ? "Igazgatóság" : s.teacher, subject: m.0, text: m.1,
                                    recipients: ["10.A"], attachments: i == 2 ? [MessageAttachment(id: 1, name: "nyilatkozat.pdf")] : [])
            }
        case .sent:
            return [KretaMessage(id: 2000, box: .sent, isRead: true, date: now.addingTimeInterval(-3 * 86_400), sender: "Demó Diák",
                                 subject: "Hiányzás", text: "Tisztelt Tanárnő!\nTegnap betegség miatt hiányoztam.",
                                 recipients: [subjects[0].teacher], attachments: [])]
        case .trash:
            return []
        }
    }

    public static let recipients: [MessageRecipient] = {
        let teacher = MessageRecipient.Kind(id: 1, code: "TANAR", description: "Tanár", name: "Tanár", shortName: "T")
        let names = Set(subjects.map(\.teacher)).sorted()
        return names.enumerated().map { MessageRecipient(kretaID: 100 + $0.offset, name: $0.element, type: teacher) }
            + [MessageRecipient(kretaID: 1, name: "Igazgatóság", type: .init(id: 2, code: "IGAZGATOSAG", description: "Igazgatóság", name: "Igazgatóság", shortName: "I"))]
    }()

    public static func wall(now: Date = .now) -> [WallItem] {
        [WallItem(id: "demo-wall-1", title: "Őszi szünet", content: "Az őszi szünet előtti utolsó tanítási nap péntek.",
                  start: now.addingTimeInterval(-5 * 86_400), end: now.addingTimeInterval(10 * 86_400)),
         WallItem(id: "demo-wall-2", title: "Fotózás", content: "Jövő kedden osztályfotózás lesz a díszteremben.",
                  start: now.addingTimeInterval(-1 * 86_400), end: now.addingTimeInterval(7 * 86_400))]
    }
}
