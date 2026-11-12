import Foundation

/// Saját jegyzetek, teendők és a késznek jelölt házik: csak a telefonon, fiókonként.
public struct Notebook: Codable, Equatable, Sendable {
    public struct Note: Codable, Identifiable, Equatable, Sendable {
        public var id = UUID()
        public var title: String
        public var text: String
        public var updated: Date
        public init(title: String, text: String, updated: Date = .now) { self.title = title; self.text = text; self.updated = updated }
    }

    public struct Todo: Codable, Identifiable, Equatable, Sendable {
        public var id = UUID()
        public var title: String
        public var isDone = false
        public var created: Date
        public init(title: String, created: Date = .now) { self.title = title; self.created = created }
    }

    public var notes: [Note] = []
    public var todos: [Todo] = []
    public var doneHomework: Set<String> = []
    /// Tantárgy id → célátlag (céltervező)
    public var goals: [String: Double] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey { case notes, todos, doneHomework, goals }

    /// Régebbi mentésekből hiányozhatnak az új mezők.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        todos = try c.decodeIfPresent([Todo].self, forKey: .todos) ?? []
        doneHomework = try c.decodeIfPresent(Set<String>.self, forKey: .doneHomework) ?? []
        goals = try c.decodeIfPresent([String: Double].self, forKey: .goals) ?? [:]
    }
}
