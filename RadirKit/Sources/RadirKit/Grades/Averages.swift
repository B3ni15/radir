import Foundation

public struct AveragePoint: Hashable, Sendable {
    public let date: Date
    public let average: Double
}

/// A legacy `AverageHelper` és a grafikon logikája.
public enum Averages {
    /// Súlyozott átlag; a nem számszerű és a 0 súlyú jegyek kimaradnak. Ha nincs mit átlagolni: nil.
    public static func weighted(_ grades: [Grade]) -> Double? {
        let gs = grades.filter(\.isNumeric)
        let total = gs.reduce(0) { $0 + Double($1.weight) }
        guard total > 0 else { return nil }
        return gs.reduce(0) { $0 + Double($1.value * $1.weight) } / total
    }

    /// A jegyszínhez: `threshold`-tól felfelé kerekít (a legacy alapja 0,5).
    public static func roundedGrade(_ average: Double, threshold: Double = 0.5) -> Int {
        let base = average.rounded(.down)
        return Int(average - base >= threshold - 1e-9 ? base + 1 : base)
    }

    /// Halmozott átlag időben: a jegyek csoportokba kerülnek, ha `gapDays`-nél közelebb vannak egymáshoz;
    /// csoportonként egy pont a legújabb dátummal és az addigi összes jegy átlagával.
    public static func timeline(_ grades: [Grade], gapDays: Int) -> [AveragePoint] {
        let sorted = grades.filter(\.isNumeric).sorted { $0.writeDate < $1.writeDate }
        var points: [AveragePoint] = []
        for (i, g) in sorted.enumerated() {
            let next = i + 1 < sorted.count ? sorted[i + 1] : nil
            let gap = next.map { $0.writeDate.timeIntervalSince(g.writeDate) / 86_400 } ?? .infinity
            if gap > Double(gapDays), let avg = weighted(Array(sorted[...i])) {
                points.append(AveragePoint(date: g.writeDate, average: avg))
            }
        }
        return points
    }

    /// Hány darab 1-es … 5-ös van (csak az átlagba számító jegyek).
    public static func distribution(_ grades: [Grade]) -> [Int: Int] {
        var d = Dictionary(uniqueKeysWithValues: (1...5).map { ($0, 0) })
        for g in grades where g.isNumeric { d[g.value, default: 0] += 1 }
        return d
    }

    /// A mostani átlag és a `days` nappal ezelőtti átlag különbsége. 0 nap (egész év) vagy hiányzó adat: nil.
    public static func trend(_ grades: [Grade], days: Int, now: Date = .now) -> Double? {
        guard days > 0, let current = weighted(grades) else { return nil }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        guard let before = weighted(grades.filter { $0.date < cutoff }) else { return nil }
        return current - before
    }
}
