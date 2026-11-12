import Foundation

/// `TanuloAdatlap`
public struct Student: Codable, Sendable, Equatable {
    public let uid: String
    public let name: String
    public let instituteCode: String
    public let schoolName: String
    public let birthDate: Date?
    public let parents: [String]
    public let address: String?
    /// Hány órával később jelennek meg a jegyek (iskolai beállítás)
    public var gradeDelayHours: Int = 0

    public init(uid: String, name: String, instituteCode: String, schoolName: String, birthDate: Date?, parents: [String], address: String?) {
        self.uid = uid
        self.name = name
        self.instituteCode = instituteCode
        self.schoolName = schoolName
        self.birthDate = birthDate
        self.parents = parents
        self.address = address
    }

    private enum KretaKeys: String, CodingKey {
        case Uid, Nev, SzuletesiNev, IntezmenyAzonosito, IntezmenyNev, SzuletesiDatum, AnyjaNeve, Gondviselok, Cimek, Intezmeny
    }

    private struct Institute: Decodable {
        struct Settings: Decodable { let ErtekelesekMegjelenitesenekKesleltetesenekMerteke: Int? }
        let TestreszabasBeallitasok: Settings?
    }

    private struct Parent: Decodable { let Nev: String? }

    public init(from decoder: Decoder) throws {
        // Saját tárolt formátum (Codable szintézis) vagy a KRÉTA válasza
        if let own = try? OwnFormat(from: decoder) {
            self.init(uid: own.uid, name: own.name, instituteCode: own.instituteCode, schoolName: own.schoolName,
                      birthDate: own.birthDate, parents: own.parents, address: own.address)
            gradeDelayHours = own.gradeDelayHours ?? 0
            return
        }
        let c = try decoder.container(keyedBy: KretaKeys.self)
        let name = try c.decodeIfPresent(String.self, forKey: .Nev) ?? c.decodeIfPresent(String.self, forKey: .SzuletesiNev) ?? ""
        var parents = (try c.decodeIfPresent([Parent].self, forKey: .Gondviselok) ?? []).compactMap(\.Nev)
        if let mother = try c.decodeIfPresent(String.self, forKey: .AnyjaNeve) { parents.insert(mother, at: 0) }
        var seen = Set<String>()
        parents = parents.map { $0.lowercased().capitalized }.filter { seen.insert($0).inserted }
        let birth = kretaDate(try c.decodeIfPresent(String.self, forKey: .SzuletesiDatum))
        self.init(
            uid: try c.decodeIfPresent(String.self, forKey: .Uid) ?? "",
            name: name.trimmingCharacters(in: .whitespaces),
            instituteCode: try c.decodeIfPresent(String.self, forKey: .IntezmenyAzonosito) ?? "",
            schoolName: try c.decodeIfPresent(String.self, forKey: .IntezmenyNev) ?? "",
            birthDate: birth,
            parents: parents,
            address: try c.decodeIfPresent([String].self, forKey: .Cimek)?.first)
        gradeDelayHours = (try? c.decodeIfPresent(Institute.self, forKey: .Intezmeny))??.TestreszabasBeallitasok?.ErtekelesekMegjelenitesenekKesleltetesenekMerteke ?? 0
    }

    private enum CodingKeys: String, CodingKey { case uid, name, instituteCode, schoolName, birthDate, parents, address, gradeDelayHours }

    private struct OwnFormat: Decodable {
        let uid, name, instituteCode, schoolName: String
        let birthDate: Date?
        let parents: [String]
        let address: String?
        let gradeDelayHours: Int?
    }
}
