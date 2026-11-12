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

    public init() {}
}
