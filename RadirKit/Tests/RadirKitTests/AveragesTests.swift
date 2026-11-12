import Foundation
import Testing
@testable import RadirKit

func grade(_ value: Int, weight: Int = 100, day: Int = 0, kind: GradeKind = .midYear, subject: String = "matek",
           text: String = "") -> Grade {
    Grade(id: UUID().uuidString, date: Date(timeIntervalSince1970: Double(day) * 86_400),
          writeDate: Date(timeIntervalSince1970: Double(day) * 86_400), value: value, valueName: text, shortName: "",
          weight: weight, kind: kind, subject: Subject(id: subject, name: subject, categoryName: ""),
          topic: "", mode: "", teacher: "", valueTypeID: "")
}

@Suite struct AveragesTests {
    @Test func weightedAverage() {
        // (5*1 + 3*2) / 3 = 3.666…
        let avg = Averages.weighted([grade(5), grade(3, weight: 200)])
        #expect(abs(avg! - 11.0 / 3) < 0.0001)
    }

    @Test func averageIgnoresBehaviorAndZero() {
        #expect(Averages.weighted([grade(5, weight: 0)]) == nil)
        #expect(Averages.weighted([grade(0)]) == nil)
        #expect(Averages.weighted([]) == nil)
        #expect(Averages.weighted([grade(4), grade(0), grade(5, weight: 0)]) == 4)
    }

    @Test func roundingThreshold() {
        #expect(Averages.roundedGrade(3.49) == 3)
        #expect(Averages.roundedGrade(3.5) == 4)
        #expect(Averages.roundedGrade(4.6, threshold: 0.7) == 4)
        #expect(Averages.roundedGrade(4.7, threshold: 0.7) == 5)
        #expect(Averages.roundedGrade(5) == 5)
    }

    @Test func timelineGroupsByGapAndIsCumulative() {
        // napok: 0, 1 | 10 | 20, 21 → 2 napos réssel három csoport
        let gs = [grade(5, day: 0), grade(3, day: 1), grade(4, day: 10), grade(2, day: 20), grade(5, day: 21)]
        let points = Averages.timeline(gs, gapDays: 2)
        #expect(points.map(\.date) == [1, 10, 21].map { Date(timeIntervalSince1970: Double($0) * 86_400) })
        #expect(points.map(\.average) == [4, 4, 3.8])
    }

    @Test func distributionCountsNumericOnly() {
        let d = Averages.distribution([grade(5), grade(5), grade(1), grade(4, weight: 0), grade(0)])
        #expect(d == [1: 1, 2: 0, 3: 0, 4: 0, 5: 2])
    }

    @Test func trendComparesWithEarlierAverage() {
        let now = Date(timeIntervalSince1970: 40 * 86_400)
        let gs = [grade(3, day: 0), grade(5, day: 35)]
        // 30 napja: csak a 3-as → 3; most 4 → +1
        #expect(Averages.trend(gs, days: 30, now: now) == 1)
        #expect(Averages.trend(gs, days: 0, now: now) == nil)
    }
}
