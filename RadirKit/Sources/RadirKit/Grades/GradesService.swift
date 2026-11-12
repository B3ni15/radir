import Foundation

public struct GradesService: Sendable {
    public init() {}

    /// Jegyek, majd az osztályátlagok. Az osztályátlag hibája nem buktatja el a jegyeket.
    public func fetch(session: KretaSession, instituteCode: String, now: Date = .now) async throws -> GradeBook {
        let base = Kreta.base(instituteCode).appending(path: "ellenorzo/V3/Sajat")
        let grades = try Grade.decodeKreta(try await session.data(for: base.appending(path: "Ertekelesek")))
        let averages = (try? await classAverages(session: session, base: base)) ?? []
        return GradeBook(grades: grades, classAverages: averages, fetchedAt: now)
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

    private func classAverages(session: KretaSession, base: URL) async throws -> [ClassAverage] {
        let groups = try await session.get([Group].self, from: base.appending(path: "OsztalyCsoportok"))
        guard let uid = groups.first?.OktatasNevelesiFeladat?.Uid, !uid.isEmpty else { return [] }
        let url = base.appending(path: "Ertekelesek/Atlagok/OsztalyAtlagok")
            .appending(queryItems: [URLQueryItem(name: "oktatasiNevelesiFeladatUid", value: uid)])
        return try await session.get([GroupAverage].self, from: url).compactMap { a in
            guard let id = a.Tantargy?.Uid, let avg = a.OsztalyCsoportAtlag else { return nil }
            return ClassAverage(subjectID: id, average: avg)
        }
    }
}
