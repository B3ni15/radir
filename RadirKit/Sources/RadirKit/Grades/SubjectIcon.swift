/// SF Symbol a tantárgy nevéből, mint a legacy tantárgyikonjai.
public enum SubjectIcon {
    private static let table: [(String, String)] = [
        ("matematika", "function"), ("magyar", "text.book.closed"), ("irodalom", "books.vertical"),
        ("nyelvtan", "textformat"), ("tortenelem", "building.columns"), ("angol", "character.bubble"),
        ("nemet", "character.bubble"), ("francia", "character.bubble"), ("spanyol", "character.bubble"),
        ("olasz", "character.bubble"), ("orosz", "character.bubble"), ("latin", "character.bubble"),
        ("fizika", "atom"), ("kemia", "flask"), ("biologia", "leaf"), ("termeszet", "leaf"),
        ("foldrajz", "globe.europe.africa"), ("informatika", "desktopcomputer"), ("digitalis", "desktopcomputer"),
        ("testneveles", "figure.run"), ("enek", "music.note"), ("zene", "music.note"),
        ("rajz", "paintpalette"), ("vizualis", "paintpalette"), ("mozgokep", "film"), ("drama", "theatermasks"),
        ("etika", "person.2"), ("hit", "person.2"), ("osztalyfonoki", "person.3"), ("technika", "hammer"),
        ("gazdasag", "chart.bar"), ("penzugy", "banknote"), ("filozofia", "brain.head.profile"),
    ]

    public static func name(for subject: Subject) -> String {
        let key = (subject.name + " " + subject.categoryName).lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        return table.first { key.contains($0.0) }?.1 ?? "book.closed"
    }
}
