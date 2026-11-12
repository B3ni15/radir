import Foundation
import Testing
@testable import RadirKit

func fixtureGrades() throws -> [Grade] {
    let url = try #require(Bundle.module.url(forResource: "Ertekelesek", withExtension: "json", subdirectory: "Fixtures"))
    return try Grade.decodeKreta(Data(contentsOf: url))
}

@Suite struct GradeTests {
    @Test func decodesNumericGrade() throws {
        let g = try fixtureGrades()[0]
        #expect(g.id == "g1")
        #expect(g.value == 5 && g.weight == 100)
        #expect(g.valueName == "Jeles")
        #expect(g.kind == .midYear)
        #expect(g.subject == Subject(id: "matek", name: "Matematika", categoryName: "matematika"))
        #expect(g.teacher == "Nagy Katalin")
        #expect(g.topic == "Függvények")
        #expect(g.mode == "Írásbeli témazáró dolgozat")
        #expect(g.date == Date(timeIntervalSince1970: 1_789_430_400))
    }

    @Test func fractionalSecondsParse() throws {
        #expect(abs(try fixtureGrades()[1].writeDate.timeIntervalSince1970 - 1_790_845_200.123) < 0.001)
    }

    @Test func behaviorTextMapsToValueWithZeroWeight() throws {
        let g = try fixtureGrades()[2]
        #expect(g.value == 5)
        #expect(g.weight == 0)
        #expect(g.isNumeric == false)
    }

    @Test func halfYearKind() throws {
        #expect(try fixtureGrades()[3].kind == .halfYear)
    }

    @Test func gradeDecodesWithMissingFields() throws {
        let g = try fixtureGrades()[4]
        #expect(g.value == 2 && g.kind == .unknown && g.subject.id == "" && g.topic == "")
    }

    @Test func cacheRoundTrip() throws {
        let grades = try fixtureGrades()
        let back = try JSONDecoder().decode([Grade].self, from: JSONEncoder().encode(grades))
        #expect(back == grades)
    }
}
