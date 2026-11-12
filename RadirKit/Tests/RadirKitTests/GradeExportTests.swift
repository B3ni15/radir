import Foundation
import Testing
@testable import RadirKit

@Suite struct GradeExportTests {
    @Test func legacyExportFields() throws {
        let data = try GradeExport.json(try fixtureGrades())
        let items = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(items.count == 5)
        let first = try #require(items.first { $0["description"] as? String == "Függvények" })
        #expect(first["subject"] as? String == "Matematika" && first["value"] as? Int == 5 && first["weight"] as? Int == 100)
        #expect(first["type"] as? String == "midYear" && first["value_name"] as? String == "Jeles")
        #expect((first["date"] as? String)?.hasPrefix("2026-09-15") == true)
    }
}
