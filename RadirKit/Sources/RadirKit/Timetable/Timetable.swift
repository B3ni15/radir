import Foundation

public enum TimetableEntry: Hashable, Sendable, Identifiable {
    case lesson(Lesson)
    /// Lyukas óra az első és az utolsó óra között. `after`: az előző óra vége.
    case free(index: Int, after: Date?)

    public var id: String {
        switch self {
        case .lesson(let l): l.id
        case .free(let i, let after): "free-\(i)-\(after?.timeIntervalSince1970 ?? 0)"
        }
    }
}

/// Egy sor a nap listájában: óra vagy lyukas óra, illetve a két óra közti szünet.
public enum TimetableItem: Hashable, Sendable, Identifiable {
    case entry(TimetableEntry)
    case pause(from: Date, to: Date)

    public var id: String {
        switch self {
        case .entry(let e): e.id
        case .pause(let from, _): "pause-\(from.timeIntervalSince1970)"
        }
    }

    public var minutes: Int? {
        if case .pause(let from, let to) = self { Int((to.timeIntervalSince(from) / 60).rounded()) } else { nil }
    }
}

public struct TimetableDay: Hashable, Sendable, Identifiable {
    public let date: Date
    public let entries: [TimetableEntry]
    public var id: Date { date }

    /// Az órák, közöttük minden szünettel. Lyukas óra után nincs szünet, mert annak nincs ideje;
    /// az események (fogadóóra stb.) nem számítanak.
    public var items: [TimetableItem] {
        var out: [TimetableItem] = []
        var lastEnd: Date?
        for entry in entries {
            switch entry {
            case .lesson(let l) where !l.isEvent:
                if let end = lastEnd, l.start.timeIntervalSince(end) >= 60 { out.append(.pause(from: end, to: l.start)) }
                lastEnd = l.end
            case .free:
                lastEnd = nil
            case .lesson:
                break
            }
            out.append(.entry(entry))
        }
        return out
    }

    public var lessons: [Lesson] {
        entries.compactMap { if case .lesson(let l) = $0 { l } else { nil } }
    }
}

public enum Timetable {
    /// A legacy `_sortDays`: napokra bont, az óraszámok közti hiányt lyukas órával tölti,
    /// az óraszám nélküli órákat időrendben a végére, az eseményeket a nap elejére teszi.
    public static func days(_ lessons: [Lesson]) -> [TimetableDay] {
        let byDay = Dictionary(grouping: lessons, by: \.date)
        return byDay.keys.sorted().map { date in
            let all = byDay[date]!
            let events = all.filter(\.isEvent).sorted { $0.start < $1.start }
            let numbered = all.filter { !$0.isEvent && $0.index != nil }
            let unnumbered = all.filter { !$0.isEvent && $0.index == nil }.sorted { $0.start < $1.start }

            var entries = events.map(TimetableEntry.lesson)
            if let lo = numbered.compactMap(\.index).min(), let hi = numbered.compactMap(\.index).max() {
                var lastEnd: Date?
                for i in lo...hi {
                    let here = numbered.filter { $0.index == i }.sorted { $0.start < $1.start }
                    if here.isEmpty {
                        entries.append(.free(index: i, after: lastEnd))
                    } else {
                        entries += here.map(TimetableEntry.lesson)
                        lastEnd = here.map(\.end).max()
                    }
                }
            }
            entries += unnumbered.map(TimetableEntry.lesson)
            return TimetableDay(date: date, entries: entries)
        }
    }
}
