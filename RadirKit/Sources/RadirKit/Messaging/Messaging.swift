import Foundation

/// Az eÜgyintézés dátumai időzóna nélkül jönnek („2026-11-11T09:30:00”), budapesti időként értelmezzük.
func adminDate(_ s: String?) -> Date? {
    guard let s else { return nil }
    if let d = kretaDate(s) { return d }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = Calendar.school.timeZone
    for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"] {
        f.dateFormat = format
        if let d = f.date(from: s) { return d }
    }
    return nil
}

public enum MailBox: String, Codable, CaseIterable, Sendable {
    case inbox = "beerkezett", sent = "elkuldott", trash = "torolt"
}

public struct MessageAttachment: Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

public struct KretaMessage: Codable, Identifiable, Hashable, Sendable {
    /// A postafiók-elem azonosítója (ezzel kérhető le a részlet)
    public let id: Int
    public let box: MailBox
    public let isRead: Bool
    public let date: Date
    public let sender: String
    public let subject: String
    /// HTML; a listában üres, a részletekben van
    public let text: String
    public let recipients: [String]
    public let attachments: [MessageAttachment]
    /// A listából tudható, mielőtt a csatolmányok betöltődnének
    public let hasAttachments: Bool

    public init(id: Int, box: MailBox, isRead: Bool, date: Date, sender: String, subject: String, hasAttachments: Bool? = nil,
                text: String, recipients: [String], attachments: [MessageAttachment]) {
        self.id = id; self.box = box; self.isRead = isRead; self.date = date; self.sender = sender
        self.subject = subject; self.text = text; self.recipients = recipients; self.attachments = attachments
        self.hasAttachments = hasAttachments ?? !attachments.isEmpty
    }

    public var plainText: String { HTMLText.plain(text.replacingOccurrences(of: "\r", with: "")) }

    struct DTO: Decodable {
        struct Inner: Decodable {
            struct Recipient: Decodable { let nev: String? }
            struct Attachment: Decodable { let azonosito: Int?; let fajlNev: String? }
            let kuldesDatum: String?; let feladoNev: String?; let targy: String?; let szoveg: String?
            let cimzettLista: [Recipient]?; let csatolmanyok: [Attachment]?
        }
        let azonosito: Int
        let isElolvasva: Bool?
        let uzenet: Inner?
        // a lista lapos formában adja ugyanezt
        let uzenetFeladoNev: String?
        let uzenetTargy: String?
        let uzenetKuldesDatum: String?
        let hasCsatolmany: Bool?
    }

    static func from(_ d: DTO, box: MailBox) -> KretaMessage {
        let u = d.uzenet
        return KretaMessage(id: d.azonosito, box: box, isRead: d.isElolvasva ?? true,
                            date: adminDate(u?.kuldesDatum ?? d.uzenetKuldesDatum) ?? .distantPast,
                            sender: (u?.feladoNev ?? d.uzenetFeladoNev ?? "").trimmingCharacters(in: .whitespaces),
                            subject: u?.targy ?? d.uzenetTargy ?? "", hasAttachments: d.hasCsatolmany ?? !(u?.csatolmanyok ?? []).isEmpty,
                            text: u?.szoveg ?? "", recipients: (u?.cimzettLista ?? []).compactMap(\.nev),
                            attachments: (u?.csatolmanyok ?? []).compactMap { a in
                                a.azonosito.map { MessageAttachment(id: $0, name: (a.fajlNev ?? "csatolmány").trimmingCharacters(in: .whitespaces)) }
                            })
    }

    public static func decodeList(_ data: Data, box: MailBox) throws -> [KretaMessage] {
        try JSONDecoder().decode([DTO].self, from: data).map { from($0, box: box) }
    }

    public static func decodeDetail(_ data: Data, box: MailBox) throws -> KretaMessage {
        from(try JSONDecoder().decode(DTO.self, from: data), box: box)
    }
}

public struct MessageRecipient: Codable, Hashable, Identifiable, Sendable {
    public struct Kind: Codable, Hashable, Sendable {
        public let id: Int
        public let code: String
        public let description: String
        public let name: String
        public let shortName: String
        public init(id: Int, code: String, description: String, name: String, shortName: String) {
            self.id = id; self.code = code; self.description = description; self.name = name; self.shortName = shortName
        }
    }

    public let kretaID: Int
    public let name: String
    public let type: Kind
    public var id: String { "\(type.code)-\(kretaID)" }

    public init(kretaID: Int, name: String, type: Kind) { self.kretaID = kretaID; self.name = name; self.type = type }

    /// Ahogy a legacy küldi (`SendRecipient.kretaJson`).
    var kretaJSON: [String: Any] {
        ["azonosito": kretaID, "kretaAzonosito": kretaID, "nev": name,
         "tipus": ["azonosito": type.id, "kod": type.code, "leiras": type.description, "nev": type.name, "rovidNev": type.shortName]]
    }
}

public enum MessagingError: Error, Equatable {
    /// Az iskola nem engedi a diáknak az üzenetküldést.
    case notAllowed
}

public struct MessagingService: Sendable {
    public static let base = URL(string: "https://eugyintezes.e-kreta.hu")!
    public init() {}

    public func list(_ box: MailBox, session: KretaSession) async throws -> [KretaMessage] {
        let url = Self.base.appending(path: "api/v1/kommunikacio/postaladaelemek/\(box.rawValue)")
        let data = try await session.data(for: url)
        return try KretaMessage.decodeList(data, box: box).sorted { $0.date > $1.date }
    }

    /// Megnyitáskor; a KRÉTA ilyenkor olvasottnak jelölheti.
    public func detail(_ id: Int, box: MailBox, session: KretaSession) async throws -> KretaMessage {
        try KretaMessage.decodeDetail(try await session.data(for: Self.base.appending(path: "api/v1/kommunikacio/postaladaelemek/\(id)")), box: box)
    }

    public func attachment(_ id: Int, session: KretaSession) async throws -> Data {
        try await session.data(for: Self.base.appending(path: "api/v1/dokumentumok/uzenetek/\(id)"))
    }

    private struct Category: Decodable {
        let azonosito: Int?; let kod: String?; let leiras: String?; let nev: String?; let rovidNev: String?
    }

    private struct Staff: Decodable { let kretaAzonosito: Int?; let nev: String? }

    /// Tanárok és igazgatóság, a legacy szerint (csak a `TANAR` és `IGAZGATOSAG` típus címezhető).
    public func recipients(session: KretaSession) async throws -> [MessageRecipient] {
        let cats = try await session.get([Category].self, from: Self.base.appending(path: "api/v1/adatszotarak/cimzetttipusok"))
        func kind(_ code: String) -> MessageRecipient.Kind? {
            cats.first { $0.kod == code }.map {
                .init(id: $0.azonosito ?? 0, code: code, description: $0.leiras ?? "", name: $0.nev ?? "", shortName: $0.rovidNev ?? "")
            }
        }
        var out: [MessageRecipient] = []
        for (code, path) in [("TANAR", "tanar"), ("IGAZGATOSAG", "igazgatosag")] {
            let staff = try await session.get([Staff].self, from: Self.base.appending(path: "api/v1/kreta/alkalmazottak/\(path)"))
            guard let k = kind(code) else { continue }
            out += staff.compactMap { s in s.kretaAzonosito.map { MessageRecipient(kretaID: $0, name: (s.nev ?? "").trimmingCharacters(in: .whitespaces), type: k) } }
        }
        let hu = Locale(identifier: "hu_HU")
        return out.sorted { $0.name.compare($1.name, locale: hu) == .orderedAscending }
    }

    public func send(to recipients: [MessageRecipient], subject: String, text: String, senderName: String, isParent: Bool,
                     session: KretaSession) async throws {
        let body: [String: Any] = [
            "cimzettLista": recipients.map(\.kretaJSON), "csatolmanyok": [], "azonosito": Int.random(in: 10_000..<20_000),
            "feladoNev": senderName, "feladoTitulus": isParent ? "Szülő" : "Diák",
            "kuldesDatum": Date.now.formatted(.iso8601), "targy": subject.isEmpty ? "Nincs tárgy" : subject, "szoveg": text,
        ]
        let response = try await session.post(json: JSONSerialization.data(withJSONObject: body),
                                              to: Self.base.appending(path: "api/v1/kommunikacio/uzenetek"))
        if let r = try? JSONSerialization.jsonObject(with: response) as? [String: Any], r["hibakod"] as? String == "UzenetKuldesEngedelyRule" {
            throw MessagingError.notAllowed
        }
    }
}

/// Faliújság elem (`FaliujsagElemek`).
public struct WallItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let content: String
    public let start: Date
    public let end: Date

    public init(id: String, title: String, content: String, start: Date, end: Date) {
        self.id = id; self.title = title; self.content = content; self.start = start; self.end = end
    }

    public var plainText: String { HTMLText.plain(content.replacingOccurrences(of: "\r", with: "")) }
    public func isValid(at date: Date) -> Bool { start <= date && date <= end }

    struct DTO: Decodable { let Uid: String?; let Cim: String?; let Tartalom: String?; let ErvenyessegKezdete: String?; let ErvenyessegVege: String? }

    public static func decodeKreta(_ data: Data) throws -> [WallItem] {
        try JSONDecoder().decode([DTO].self, from: data).map { d in
            WallItem(id: d.Uid ?? UUID().uuidString, title: d.Cim ?? "", content: d.Tartalom ?? "",
                     start: kretaDate(d.ErvenyessegKezdete) ?? .distantPast, end: kretaDate(d.ErvenyessegVege) ?? .distantFuture)
        }
    }
}

extension SchoolDataService {
    public func wall(session: KretaSession, instituteCode: String) async throws -> [WallItem] {
        try WallItem.decodeKreta(try await session.data(for: Kreta.base(instituteCode).appending(path: "ellenorzo/V3/Sajat/FaliujsagElemek")))
    }
}
