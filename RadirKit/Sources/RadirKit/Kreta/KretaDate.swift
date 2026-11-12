import Foundation

/// A KRÉTA ISO 8601 dátumai, tört másodperccel vagy anélkül.
func kretaDate(_ s: String?) -> Date? {
    guard let s else { return nil }
    return (try? Date(s, strategy: .iso8601))
        ?? (try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
}
