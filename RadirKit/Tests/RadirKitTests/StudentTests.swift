import Foundation
import Testing
@testable import RadirKit

@Suite struct StudentTests {
    @Test func studentDecodes() throws {
        let url = try #require(Bundle.module.url(forResource: "TanuloAdatlap", withExtension: "json", subdirectory: "Fixtures"))
        let s = try JSONDecoder().decode(Student.self, from: Data(contentsOf: url))
        #expect(s.uid == "123456")
        #expect(s.name == "Teszt Elek")
        #expect(s.instituteCode == "klik035046001")
        #expect(s.schoolName == "Teszt Gimnázium")
        #expect(s.parents == ["Teszt Anya", "Teszt Apa"])
        #expect(s.address == "1117 Budapest, Teszt utca 1.")
        #expect(s.birthDate != nil)
    }

    @Test func studentDecodesWithMissingOptionalFields() throws {
        let json = #"{"Uid":"1","SzuletesiNev":"  Kis Pista ","IntezmenyAzonosito":"k","IntezmenyNev":"Isk"}"#
        let s = try JSONDecoder().decode(Student.self, from: Data(json.utf8))
        #expect(s.name == "Kis Pista")
        #expect(s.parents.isEmpty && s.address == nil && s.birthDate == nil)
    }
}
