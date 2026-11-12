import Foundation

public struct GradesService: Sendable {
    public init() {}

    /// Jegyek, majd az osztályátlagok. Az osztályátlag hibája nem buktatja el a jegyeket.
    public func fetch(session: KretaSession, instituteCode: String, now: Date = .now) async throws -> GradeBook {
        let base = Kreta.base(instituteCode).appending(path: "ellenorzo/V3/Sajat")
        let grades = try Grade.decodeKreta(try await session.data(for: base.appending(path: "Ertekelesek")))
        let (averages, subjects) = (try? await groupData(session: session, base: base)) ?? ([], nil)
        var book = GradeBook(grades: grades, classAverages: averages, fetchedAt: now)
        book.allSubjects = subjects
        return book
    }

    private struct Group: Decodable {
        struct Task: Decodable { let Uid: String? }
        let OktatasNevelesiFeladat: Task?
    }

    private struct GroupAverage: Decodable {
        struct Ref: Decodable { let Uid: String? }
        let OsztalyCsoportAtlag: Double?
        let Tantargy: Ref?
    }

    private struct SubjectAverage: Decodable {
        struct Ref: Decodable { let Uid: String?; let Nev: String?; let Kategoria: Cat? }
        struct Cat: Decodable { let Nev: String? }
        let Tantargy: Ref?
    }

    /// Osztályátlagok, és a csoport összes tantárgya (a jegy nélküliek is).
    private func groupData(session: KretaSession, base: URL) async throws -> ([ClassAverage], [Subject]?) {
        let groups = try await session.get([Group].self, from: base.appending(path: "OsztalyCsoportok"))
        guard let uid = groups.first?.OktatasNevelesiFeladat?.Uid, !uid.isEmpty else { return ([], nil) }
        let query = [URLQueryItem(name: "oktatasiNevelesiFeladatUid", value: uid)]
        let averages = try await session.get([GroupAverage].self, from: base.appending(path: "Ertekelesek/Atlagok/OsztalyAtlagok").appending(queryItems: query))
            .compactMap { a -> ClassAverage? in
                guard let id = a.Tantargy?.Uid, let avg = a.OsztalyCsoportAtlag else { return nil }
                return ClassAverage(subjectID: id, average: avg)
            }
        let subjects = try? await session.get([SubjectAverage].self, from: base.appending(path: "Ertekelesek/Atlagok/TantargyiAtlagok").appending(queryItems: query))
            .compactMap { s -> Subject? in
                guard let id = s.Tantargy?.Uid, !id.isEmpty else { return nil }
                return Subject(id: id, name: (s.Tantargy?.Nev ?? "").trimmingCharacters(in: .whitespaces), categoryName: s.Tantargy?.Kategoria?.Nev ?? "")
            }
        return (averages, subjects)
    }
}
