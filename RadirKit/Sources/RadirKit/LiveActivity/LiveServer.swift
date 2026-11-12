import Foundation

/// A `refilc-live-server` Live Activity végpontjai. A Radír a `refilc` formátumot használja.
public struct LiveServer: Sendable {
    public static let production = URL(string: "https://legacy-la.devbeni.lol")!

    let baseURL: URL
    let transport: any HTTPTransport

    public init(baseURL: URL = LiveServer.production, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public struct ScheduleRequest: Encodable, Sendable {
        struct Item: Encodable {
            let type, index, subject, icon, room, description: String
            let start, end: Int64
            var nextSubject: String?
            var nextIcon: String?
            var nextRoom: String?
            var nextIndex: String?
        }

        let device_id: String
        let date: String
        let lessons: [Item]

        /// A legacy feltöltése: órák, és két óra között szünet elem a következő óra adataival.
        public init(deviceID: String, lessons: [Lesson]) {
            device_id = deviceID
            date = (lessons.first?.date ?? .now)
                .formatted(Date.ISO8601FormatStyle(timeZone: Calendar.school.timeZone).year().month().day())
            let ms = { (d: Date) in Int64((d.timeIntervalSince1970 * 1000).rounded()) }
            var items: [Item] = []
            for (i, l) in lessons.enumerated() {
                items.append(Item(type: "lesson", index: l.index.map(String.init) ?? "", subject: l.title,
                                  icon: SubjectIcon.name(for: l.subject), room: l.room, description: l.topic,
                                  start: ms(l.start), end: ms(l.end)))
                if i + 1 < lessons.count, l.end < lessons[i + 1].start {
                    let n = lessons[i + 1]
                    items.append(Item(type: "break", index: "", subject: "Szünet", icon: "cup.and.saucer", room: "",
                                      description: "", start: ms(l.end), end: ms(n.start), nextSubject: n.title,
                                      nextIcon: SubjectIcon.name(for: n.subject), nextRoom: n.room,
                                      nextIndex: n.index.map(String.init) ?? ""))
                }
            }
            self.lessons = items
        }
    }

    public func register(deviceID: String, pushToken: String, bundleID: String, color: String) async throws {
        try await post("register", [
            "device_id": deviceID, "apns_token": pushToken, "bundle_id": bundleID, "app_type": "refilc",
            "settings": ["live_activity_color": color],
        ] as [String: Any])
    }

    public func uploadSchedule(_ request: ScheduleRequest) async throws {
        try await send("schedule", body: JSONEncoder().encode(request))
    }

    public func unregister(deviceID: String) async throws {
        try await post("unregister", ["device_id": deviceID])
    }

    private func post(_ path: String, _ body: [String: Any]) async throws {
        try await send(path, body: JSONSerialization.data(withJSONObject: body))
    }

    private func send(_ path: String, body: Data) async throws {
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (_, res) = try await transport.send(req)
        guard (200..<300).contains(res.statusCode) else { throw KretaError.http(res.statusCode) }
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// Az app és a widget közös típusa. A tartalom a szerver formátuma.
public struct RadirLiveAttributes: ActivityAttributes {
    public typealias ContentState = LiveCardContent
    public init() {}
}
#endif
