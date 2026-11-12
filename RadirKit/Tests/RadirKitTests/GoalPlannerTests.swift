import Foundation
import Testing
@testable import RadirKit

@Suite struct GoalPlannerTests {
    @Test func alreadyReached() {
        #expect(GoalPlanner.solve(goal: 4, grades: [grade(5), grade(4)]) == .reached)
    }

    @Test func twoFivesFromThrees() {
        // (3+3+5+5)/4 = 4,00 → pontosan elég; 4-es nem jöhet szóba, mert nem nagyobb a célnál
        guard case .plans(let rec, let fastest, _) = GoalPlanner.solve(goal: 4, grades: [grade(3), grade(3)]) else {
            Issue.record("nincs terv"); return
        }
        #expect(rec.grades == [5, 5])
        #expect(fastest == nil)
    }

    @Test func mixedPlansOffered() {
        // 2 + 3 → cél 4: 5-ösökkel és 5+4 keverékkel is elérhető
        guard case .plans(let rec, _, let others) = GoalPlanner.solve(goal: 3.9, grades: [grade(2), grade(3)]) else {
            Issue.record("nincs terv"); return
        }
        let all = [rec] + others
        #expect(all.allSatisfy { p in Averages.weighted([grade(2), grade(3)] + p.grades.map { grade($0) })! >= 3.9 })
        #expect(Set(all.map(\.grades)).count == all.count, "nincs duplikált terv")
    }

    @Test func impossibleWhenGoalIsFive() {
        #expect(GoalPlanner.solve(goal: 5, grades: [grade(4)]) == .unsolvable)
    }

    @Test func tooManyNeeded() {
        let heavyOnes = (0..<5).map { _ in grade(1, weight: 400) }
        #expect(GoalPlanner.solve(goal: 4.5, grades: heavyOnes) == .unreachable)
    }

    @Test func howManyNeededMatchesLegacy() {
        // 2 db 3-as (súly 1+1) → 4-es átlaghoz 2 db 5-ös kell
        #expect(GoalPlanner.howManyNeeded(grade: 5, avg: 3, weightSum: 2, goal: 4) == 2)
        #expect(GoalPlanner.howManyNeeded(grade: 5, avg: 4.5, weightSum: 2, goal: 4) == 0)
        #expect(GoalPlanner.howManyNeeded(grade: 4, avg: 3, weightSum: 2, goal: 4) == -1)
    }

    @Test func calculatorGhostGrade() {
        let s = Subject(id: "m", name: "M", categoryName: "")
        let ghost = Grade.ghost(value: 5, weight: 200, subject: s)
        #expect(ghost.isNumeric && ghost.kind == .midYear && ghost.weight == 200)
        #expect(Averages.weighted([grade(3), ghost]) == (3.0 + 10.0) / 3.0)
    }
}

@Suite struct NotebookCompatTests {
    @Test func oldSaveWithoutGoalsLoads() throws {
        let old = #"{"notes":[],"todos":[],"doneHomework":["h1"]}"#
        let nb = try JSONDecoder().decode(Notebook.self, from: Data(old.utf8))
        #expect(nb.doneHomework == ["h1"] && nb.goals.isEmpty)
    }
}
