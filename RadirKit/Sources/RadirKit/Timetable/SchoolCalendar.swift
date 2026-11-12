import Foundation

extension Calendar {
    /// Az iskolai idő Budapesten van, akárhol is a telefon. A hét hétfőn kezdődik.
    public static let school: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Budapest")!
        c.locale = Locale(identifier: "hu_HU")
        c.firstWeekday = 2
        return c
    }()
}

/// Egy tanítási hét hétfőtől vasárnapig, budapesti idő szerint.
public struct SchoolWeek: Hashable, Codable, Sendable {
    /// Hétfő 00:00
    public let start: Date

    public init(containing date: Date) {
        let cal = Calendar.school
        start = cal.dateInterval(of: .weekOfYear, for: date)!.start
    }

    /// Vasárnap 00:00, ahogy a legacy kéri a KRÉTA-tól.
    public var end: Date { Calendar.school.date(byAdding: .day, value: 6, to: start)! }
    public var next: SchoolWeek { SchoolWeek(containing: Calendar.school.date(byAdding: .day, value: 7, to: start)!) }
    public var previous: SchoolWeek { SchoolWeek(containing: Calendar.school.date(byAdding: .day, value: -7, to: start)!) }

    /// Hétfőtől péntekig.
    public var days: [Date] { (0..<5).map { Calendar.school.date(byAdding: .day, value: $0, to: start)! } }

    /// Hányadik hét a tanévben (1-től), a legacy számolása szerint.
    public var number: Int {
        // a hét végéből, mert az első hét hétfője még augusztusba eshet
        let days = start.timeIntervalSince(Self.schoolYearStart(for: end)) / 86_400
        return Int((days / 7).rounded(.up)) + 1
    }

    /// Szeptember 1., vagy ha hétvégére esik, az utána jövő hétfő. Szeptember előtt az előző évé.
    public static func schoolYearStart(for date: Date) -> Date {
        let cal = Calendar.school
        func start(_ year: Int) -> Date {
            let sep1 = cal.date(from: DateComponents(year: year, month: 9, day: 1))!
            return switch cal.component(.weekday, from: sep1) {
            case 7: cal.date(byAdding: .day, value: 2, to: sep1)!
            case 1: cal.date(byAdding: .day, value: 1, to: sep1)!
            default: sep1
            }
        }
        let year = cal.component(.year, from: date)
        let this = start(year)
        return this <= date ? this : start(year - 1)
    }
}
