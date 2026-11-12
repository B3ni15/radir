import Foundation

public struct TimetableService: Sendable {
    public init() {}

    public func fetch(session: KretaSession, instituteCode: String, week: SchoolWeek) async throws -> [Lesson] {
        let iso = Date.ISO8601FormatStyle()
        let url = Kreta.base(instituteCode).appending(path: "ellenorzo/V3/Sajat/OrarendElemek").appending(queryItems: [
            URLQueryItem(name: "datumTol", value: week.start.formatted(iso)),
            URLQueryItem(name: "datumIg", value: week.end.formatted(iso)),
        ])
        return try Lesson.decodeKreta(try await session.data(for: url))
    }
}
