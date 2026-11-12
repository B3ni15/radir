import Foundation
import Testing
@testable import RadirKit

@Suite struct TimetableServiceTests {
    @Test func fetchesWeekWithUTCRange() async throws {
        let url = try #require(Bundle.module.url(forResource: "OrarendElemek", withExtension: "json", subdirectory: "Fixtures"))
        let t = MockTransport([(200, try String(contentsOf: url, encoding: .utf8))])
        let s = KretaSession(instituteCode: "klik1", tokens: TokenSet(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture),
                             auth: AuthClient(transport: t), transport: t, userAgent: "UA", onTokensChanged: { _ in })
        let week = SchoolWeek(containing: budapest(2026, 11, 12))
        let lessons = try await TimetableService().fetch(session: s, instituteCode: "klik1", week: week)
        #expect(lessons.count == 6)
        let comps = try #require(URLComponents(url: t.requests[0].url!, resolvingAgainstBaseURL: false))
        #expect(comps.path == "/ellenorzo/V3/Sajat/OrarendElemek")
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(q["datumTol"] == "2026-11-08T23:00:00Z")
        #expect(q["datumIg"] == "2026-11-14T23:00:00Z")
    }

    @Test func demoWeekHasLessonsOnWeekdays() {
        let week = SchoolWeek(containing: budapest(2026, 11, 12))
        let days = Timetable.days(Demo.lessons(for: week))
        #expect(days.count == 5)
        #expect(days.allSatisfy { $0.lessons.count >= 4 })
        #expect(days.flatMap(\.lessons).contains { $0.isCancelled })
        #expect(days.flatMap(\.lessons).contains { $0.isSubstitution })
        #expect(Demo.lessons(for: week).allSatisfy { week.days.contains($0.date) })
    }
}
