import Foundation
import Observation
import RadirKit

/// Hírek és a távoli config a saját szerverről; mindkettő tárolva, hogy offline is legyen.
@Observable
final class ServerModel {
    private(set) var news: [RadirServer.NewsItem] = []
    private let server = RadirServer()
    private let d = UserDefaults.standard

    init() {
        if let data = d.data(forKey: "newsCache"), let n = try? JSONDecoder().decode([RadirServer.NewsItem].self, from: data) { news = n }
    }

    var visibleNews: [RadirServer.NewsItem] { news.filter { ($0.expireDate ?? .distantFuture) > .now } }
    var unseenEmergency: RadirServer.NewsItem? {
        let seen = Set(d.stringArray(forKey: "seenNews") ?? [])
        return visibleNews.first { $0.emergency && !seen.contains($0.id) }
    }

    func markSeen(_ item: RadirServer.NewsItem) {
        d.set(Array(Set(d.stringArray(forKey: "seenNews") ?? []).union([item.id])), forKey: "seenNews")
        news = news // a jelvény frissüljön
    }

    func refresh() async {
        if let n = try? await server.news(bundleID: Bundle.main.bundleIdentifier ?? "hu.radirapp.ios") {
            news = n
            d.set(try? JSONEncoder().encode(n), forKey: "newsCache")
        }
        // a KRÉTA user agent sablonja: ha a KRÉTA letiltana egyet, app frissítés nélkül cserélhető
        if let ua = try? await server.config()["user_agent"], !ua.isEmpty { d.set(ua, forKey: "userAgentTemplate") }
    }

    static var userAgentTemplate: String { UserDefaults.standard.string(forKey: "userAgentTemplate") ?? "hu.ekreta.student/$0/$1/$2" }
}
