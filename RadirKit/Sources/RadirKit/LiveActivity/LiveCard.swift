import Foundation

/// A Live Activity tartalma. A mezőnevek és a dátumformátum (Apple referencia másodperc, `date` tömbként)
/// egyeznek a `refilc-live-server` `ContentState`-jével, így a szerver pushai közvetlenül dekódolhatók.
public struct LiveCardContent: Codable, Hashable, Sendable {
    public var color: String
    public var icon: String
    public var index: String
    public var title: String
    public var subtitle: String
    public var description: String
    public var startDate: Date
    public var endDate: Date
    public var date: ClosedRange<Date>
    public var nextSubject: String
    public var nextRoom: String

    public init(color: String, icon: String, index: String, title: String, subtitle: String, description: String,
                startDate: Date, endDate: Date, nextSubject: String, nextRoom: String) {
        self.color = color; self.icon = icon; self.index = index; self.title = title; self.subtitle = subtitle
        self.description = description; self.startDate = startDate; self.endDate = endDate
        date = min(startDate, endDate)...endDate
        self.nextSubject = nextSubject; self.nextRoom = nextRoom
    }
}

/// A szerver `determine_phase` logikája, hogy az app előtérben ugyanazt mutassa, amit a szerver pushol.
public enum LiveCard {
    public enum Phase: Equatable, Sendable {
        /// Az első óra előtt több mint egy órával: még nincs aktivitás
        case tooEarly
        case active(LiveCardContent)
        /// Az utolsó óra után: ezzel zárul az aktivitás
        case finished(LiveCardContent)
    }

    /// Mint a legacy: az elmaradt órák kimaradnak (kivéve, ha van helyettes), az események is.
    public static func relevant(_ lessons: [Lesson]) -> [Lesson] {
        lessons.filter { (!$0.isCancelled || $0.isSubstitution) && !$0.isEvent }.sorted { $0.start < $1.start }
    }

    public static func phase(_ lessons: [Lesson], now: Date, color: String) -> Phase {
        let ls = relevant(lessons)
        guard let lastEnd = ls.map(\.end).max() else { return .tooEarly }
        if now >= lastEnd {
            return .finished(LiveCardContent(color: color, icon: "checkmark.circle", index: "", title: "Mára vége",
                                             subtitle: "", description: "Az összes órád befejeződött",
                                             startDate: lastEnd, endDate: lastEnd, nextSubject: "", nextRoom: ""))
        }
        let next = ls.first { $0.start > now }
        if let current = ls.first(where: { $0.start <= now && now < $0.end }) {
            return .active(LiveCardContent(
                color: color, icon: SubjectIcon.name(for: current.subject), index: current.index.map { "\($0). " } ?? "",
                title: current.title, subtitle: "Terem: \(current.room)", description: current.topic,
                startDate: current.start, endDate: current.end,
                nextSubject: next?.title ?? "", nextRoom: next?.room ?? ""))
        }
        guard let next else { return .tooEarly }
        if let prev = ls.last(where: { $0.end <= now }) {
            return .active(LiveCardContent(
                color: color, icon: "cup.and.saucer", index: "", title: "Szünet", subtitle: "",
                description: "Menj a(z) \(next.room) terembe", startDate: prev.end, endDate: next.start,
                nextSubject: next.title, nextRoom: next.room))
        }
        guard next.start.timeIntervalSince(now) <= 60 * 60 else { return .tooEarly }
        return .active(LiveCardContent(
            color: color, icon: SubjectIcon.name(for: next.subject), index: "", title: "Az első órádig:", subtitle: "",
            description: "", startDate: now, endDate: next.start, nextSubject: next.title, nextRoom: next.room))
    }
}
