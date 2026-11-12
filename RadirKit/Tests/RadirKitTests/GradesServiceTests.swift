import Foundation
import Testing
@testable import RadirKit

@Suite struct GradesServiceTests {
    func session(_ t: MockTransport) -> KretaSession {
        KretaSession(instituteCode: "klik1", tokens: TokenSet(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture),
                     auth: AuthClient(transport: t), transport: t, userAgent: "UA", onTokensChanged: { _ in })
    }

    func gradesJSON() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "Ertekelesek", withExtension: "json", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func fetchesGradesAndClassAverages() async throws {
        let t = MockTransport([
            (200, try gradesJSON()),
            (200, #"[{"OktatasNevelesiFeladat":{"Uid":"1,Gimnazium"}}]"#),
            (200, #"[{"Uid":"x","OsztalyCsoportAtlag":3.75,"Tantargy":{"Uid":"matek","Nev":"Matematika"}}]"#),
        ])
        let book = try await GradesService().fetch(session: session(t), instituteCode: "klik1", now: Date(timeIntervalSince1970: 5))
        #expect(book.grades.count == 5)
        #expect(book.classAverages == [ClassAverage(subjectID: "matek", average: 3.75)])
        #expect(book.fetchedAt == Date(timeIntervalSince1970: 5))
        #expect(t.requests.map { $0.url!.absoluteString } == [
            "https://klik1.e-kreta.hu/ellenorzo/V3/Sajat/Ertekelesek",
            "https://klik1.e-kreta.hu/ellenorzo/V3/Sajat/OsztalyCsoportok",
            "https://klik1.e-kreta.hu/ellenorzo/V3/Sajat/Ertekelesek/Atlagok/OsztalyAtlagok?oktatasiNevelesiFeladatUid=1,Gimnazium",
        ])
    }

    @Test func classAverageFailureKeepsGrades() async throws {
        let t = MockTransport([(200, try gradesJSON()), (500, "")])
        let book = try await GradesService().fetch(session: session(t), instituteCode: "klik1")
        #expect(book.grades.count == 5 && book.classAverages.isEmpty)
    }

    @Test func gradesFailureThrows() async {
        let t = MockTransport([(500, "")])
        await #expect(throws: KretaError.http(500)) { try await GradesService().fetch(session: session(t), instituteCode: "klik1") }
    }

    @Test func bookQueries() throws {
        let book = GradeBook(grades: try fixtureGrades(), classAverages: [ClassAverage(subjectID: "matek", average: 3.5)], fetchedAt: .now)
        let matek = try #require(book.subjects.first { $0.id == "matek" })
        #expect(book.subjects.map(\.id).contains("magatartas") == false)
        #expect(book.grades(for: matek).map(\.id) == ["g2", "g1"])
        #expect(book.finals(for: matek).map(\.id) == ["g4"])
        #expect(book.classAverage(for: matek) == 3.5)
        #expect(book.overallClassAverage == 3.5)
    }

    @Test func cacheOnDisk() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "cache-\(UUID())")
        let cache = AccountCache(root: root)
        let book = GradeBook(grades: try fixtureGrades(), classAverages: [], fetchedAt: Date(timeIntervalSince1970: 1))
        try cache.save(book, as: "grades", for: "klik1/user")
        #expect(cache.load(GradeBook.self, as: "grades", for: "klik1/user") == book)
        #expect(cache.load(GradeBook.self, as: "grades", for: "other") == nil)
        cache.removeAll(for: "klik1/user")
        #expect(cache.load(GradeBook.self, as: "grades", for: "klik1/user") == nil)
    }

    @Test func demoIsStableWithinADayButChangesDaily() {
        let a = Demo.gradeBook(now: Date(timeIntervalSince1970: 1_800_000_000))
        let b = Demo.gradeBook(now: Date(timeIntervalSince1970: 1_800_000_000 + 600))
        let c = Demo.gradeBook(now: Date(timeIntervalSince1970: 1_800_000_000 + 86_400))
        #expect(a.grades.map(\.value) == b.grades.map(\.value))
        #expect(a.grades.map(\.value) != c.grades.map(\.value))
        #expect(!Demo.absences().isEmpty && !Demo.homework().isEmpty && !Demo.exams().isEmpty && !Demo.schoolNotes().isEmpty)
        // demóban sincs iskola hétvégén
        let cal = Calendar.school
        #expect(Demo.absences().allSatisfy { !cal.isDateInWeekend($0.date) })
        #expect(Demo.exams().allSatisfy { !cal.isDateInWeekend($0.date) })
        #expect(Demo.homework().allSatisfy { !cal.isDateInWeekend($0.deadline) })
    }

    @Test func demoBookIsPlausible() {
        let book = Demo.gradeBook(now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(book.subjects.count >= 8)
        #expect(book.grades.allSatisfy { $0.date <= Date(timeIntervalSince1970: 1_800_000_000) })
        let avg = Averages.weighted(book.grades.filter { $0.kind == .midYear })!
        #expect((3.0...5.0).contains(avg))
    }
}
