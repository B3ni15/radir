import Foundation

public struct GoalPlan: Hashable, Sendable {
    /// A szükséges jegyek csökkenő sorrendben (mind 100%-os súllyal)
    public let grades: [Int]
    public let average: Double
    /// Szórás: 0, ha mind ugyanaz a jegy
    public let sigma: Double

    init(_ grades: [Int]) {
        self.grades = grades
        average = grades.isEmpty ? 0 : Double(grades.reduce(0, +)) / Double(grades.count)
        let avg = average
        sigma = grades.isEmpty ? 0 : (grades.map { pow(Double($0) - avg, 2) }.reduce(0, +) / Double(grades.count)).squareRoot()
    }
}

public enum GoalResult: Equatable, Sendable {
    case reached
    /// Ezzel a céllal nem érhető el (pl. 5,00 egy 4-es után)
    case unsolvable
    /// Elérhető, de túl sok jegy kellene (20 felett)
    case unreachable
    case plans(recommended: GoalPlan, fastest: GoalPlan?, others: [GoalPlan])
}

/// A legacy céltervezője (refilc_plus `GoalPlanner`, „translated from C”), Swiftben.
public enum GoalPlanner {
    /// Hány darab `grade` kell ahhoz, hogy az átlag elérje a célt; -1, ha ezzel a jeggyel sosem.
    static func howManyNeeded(grade: Int, avg: Double, weightSum: Double, goal: Double) -> Int {
        if avg >= goal { return 0 }
        if Double(grade) == goal { return -1 }
        let candidate = Int((weightSum * (avg - goal) / (goal - Double(grade))).rounded(.down))
        let reached = (Double(candidate * grade) + avg * weightSum) / (Double(candidate) + weightSum)
        return reached < goal ? candidate + 1 : candidate
    }

    public static func solve(goal: Double, grades: [Grade]) -> GoalResult {
        let base = grades.filter(\.isNumeric)
        let weightSum = base.reduce(0) { $0 + Double($1.weight) / 100 }
        let avg = Averages.weighted(base) ?? 0
        if avg >= goal { return .reached }

        var found: [[Int]] = []
        // mélységi keresés: 5-ösöktől lefelé, mindig csak a célnál nagyobb jegyekkel
        func generate(gradeToAdd: Int, max: Int, avg: Double, n: Double, plan: [Int]) {
            if avg >= goal { found.append(plan); return }
            guard Double(gradeToAdd) > goal, max >= 0 else { return }
            for i in stride(from: max, through: 0, by: -1) {
                let newPlan = plan + Array(repeating: gradeToAdd, count: i)
                let newN = n + Double(i)
                let newAvg = (avg * n + Double(gradeToAdd * i)) / newN
                let next = gradeToAdd - 1
                generate(gradeToAdd: next, max: howManyNeeded(grade: next, avg: newAvg, weightSum: newN, goal: goal),
                         avg: newAvg, n: newN, plan: newPlan)
            }
        }
        generate(gradeToAdd: 5, max: howManyNeeded(grade: 5, avg: avg, weightSum: weightSum, goal: goal), avg: avg, n: weightSum, plan: [])

        var plans = Array(Set(found)).map(GoalPlan.init)
        if plans.contains(where: { $0.grades.count < 30 }) { plans.removeAll { $0.grades.count >= 30 } }
        if plans.contains(where: { $0.sigma > 1 }) { plans.removeAll { $0.sigma <= 1 } }

        // ajánlott: az átlaga a legközelebb a (2·cél + 5) / 3-hoz, és nem csupa egyforma jegy
        let target = (2 * goal + 5) / 3
        plans.sort { abs($0.average - target) != abs($1.average - target) ? abs($0.average - target) < abs($1.average - target) : $0.grades.lexicographicallyPrecedes($1.grades) }
        let singleSolution = plans.allSatisfy { $0.sigma == 0 }
        guard var recommended = plans.first(where: { singleSolution || $0.sigma > 0 }) else { return .unsolvable }
        plans.removeAll { $0 == recommended }
        plans.sort { $0.grades.count != $1.grades.count ? $0.grades.count < $1.grades.count : $0.grades.lexicographicallyPrecedes($1.grades) }
        var fastest = plans.isEmpty ? nil : plans.removeFirst()
        if let f = fastest, recommended.grades.count - f.grades.count >= 5 {
            plans.insert(recommended, at: 0)
            recommended = f
            fastest = nil
        }
        if recommended.grades.count > 20 { return .unreachable }
        return .plans(recommended: recommended, fastest: fastest, others: plans)
    }
}

extension Grade {
    /// Elképzelt jegy a jegykalkulátorhoz.
    public static func ghost(value: Int, weight: Int, subject: Subject, date: Date = .now) -> Grade {
        Grade(id: "ghost-\(UUID().uuidString)", date: date, writeDate: date, value: value, valueName: "", shortName: String(value),
              weight: weight, kind: .midYear, subject: subject, topic: "", mode: "", teacher: "", valueTypeID: "ghost")
    }

    public var isGhost: Bool { valueTypeID == "ghost" }
}
