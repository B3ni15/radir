import Foundation

/// Jegyexport a legacy export-formátumában (amit a legacy `Grade.fromExportJson` vissza is tud olvasni).
public enum GradeExport {
    public static func json(_ grades: [Grade]) throws -> Data {
        let items: [[String: Any]] = grades.sorted { $0.date < $1.date }.map { g in
            ["subject": g.subject.name, "value": g.value, "value_name": g.valueName,
             "date": g.date.formatted(.iso8601), "weight": g.weight, "type": g.kind.rawValue,
             "description": g.topic, "teacher": g.teacher]
        }
        return try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys])
    }
}
