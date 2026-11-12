import Foundation
import Testing
@testable import RadirKit

@Suite struct LiveCardTests {
    let day = budapest(2026, 11, 12)
    func at(_ h: Int, _ m: Int) -> Date { budapest(2026, 11, 12, h, m) }

    func lesson(_ i: Int, _ name: String, _ h: Int, _ m: Int, room: String = "201", cancelled: Bool = false,
                substitute: String? = nil, topic: String = "") -> Lesson {
        Lesson(id: "\(i)", date: day, start: at(h, m), end: at(h, m).addingTimeInterval(45 * 60),
               subject: Subject(id: name, name: name, categoryName: ""), index: i, yearIndex: nil, name: name,
               teacher: "", substituteTeacher: substitute, room: room, topic: topic, groupName: "",
               isCancelled: cancelled, wasAbsent: false, homeworkID: nil, examID: nil, isOnline: false)
    }

    var lessons: [Lesson] {
        [lesson(1, "Matematika", 8, 0, topic: "Egyenletek"), lesson(2, "Fizika", 8, 55, room: "Fizika előadó"),
         lesson(3, "Kémia", 9, 50, cancelled: true), lesson(4, "Biológia", 10, 50, cancelled: true, substitute: "X Y")]
    }

    @Test func filtersCancelledButKeepsSubstituted() {
        #expect(LiveCard.relevant(lessons).map(\.id) == ["1", "2", "4"])
    }

    @Test func tooEarly() {
        #expect(LiveCard.phase(lessons, now: at(6, 59), color: "#2F6FEB") == .tooEarly)
    }

    @Test func morningCountdown() throws {
        guard case .active(let c) = LiveCard.phase(lessons, now: at(7, 10), color: "#2F6FEB") else { Issue.record(); return }
        #expect(c.title == "Az első órádig:")
        #expect(c.icon == "function")
        #expect(c.date == at(7, 10)...at(8, 0))
        #expect(c.nextSubject == "Matematika" && c.nextRoom == "201")
        #expect(c.color == "#2F6FEB")
    }

    @Test func duringLesson() {
        guard case .active(let c) = LiveCard.phase(lessons, now: at(8, 20), color: "#2F6FEB") else { Issue.record(); return }
        #expect(c.index == "1. " && c.title == "Matematika" && c.subtitle == "Terem: 201")
        #expect(c.description == "Egyenletek")
        #expect(c.startDate == at(8, 0) && c.endDate == at(8, 45))
        #expect(c.nextSubject == "Fizika" && c.nextRoom == "Fizika előadó")
    }

    @Test func duringBreak() {
        guard case .active(let c) = LiveCard.phase(lessons, now: at(8, 50), color: "#2F6FEB") else { Issue.record(); return }
        #expect(c.title == "Szünet" && c.icon == "cup.and.saucer")
        #expect(c.description == "Menj a(z) Fizika előadó terembe")
        #expect(c.date == at(8, 45)...at(8, 55))
    }

    @Test func finished() {
        guard case .finished(let c) = LiveCard.phase(lessons, now: at(11, 40), color: "#2F6FEB") else { Issue.record(); return }
        #expect(c.title == "Mára vége" && c.date == at(11, 35)...at(11, 35))
        #expect(LiveCard.phase([], now: at(9, 0), color: "") == .tooEarly)
    }

    @Test func contentStateMatchesServerJSON() throws {
        let c = LiveCardContent(color: "#fff", icon: "i", index: "1. ", title: "t", subtitle: "s", description: "d",
                                startDate: Date(timeIntervalSinceReferenceDate: 100), endDate: Date(timeIntervalSinceReferenceDate: 200),
                                nextSubject: "n", nextRoom: "r")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(c)) as! [String: Any]
        #expect(Set(json.keys) == ["color", "icon", "index", "title", "subtitle", "description", "startDate", "endDate", "date", "nextSubject", "nextRoom"])
        #expect(json["startDate"] as? Double == 100)
        #expect(json["date"] as? [Double] == [100, 200])
        // a szerver által küldött formátumot vissza is tudjuk olvasni
        let server = ##"{"color":"#fff","icon":"i","index":"","title":"Szünet","subtitle":"","description":"","startDate":100,"endDate":200,"date":[100,200],"nextSubject":"n","nextRoom":"r"}"##
        #expect(try JSONDecoder().decode(LiveCardContent.self, from: Data(server.utf8)).title == "Szünet")
    }

    @Test func scheduleUploadPayload() throws {
        let body = LiveServer.ScheduleRequest(deviceID: "dev", lessons: LiveCard.relevant(lessons))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as! [String: Any]
        #expect(json["device_id"] as? String == "dev")
        #expect(json["date"] as? String == "2026-11-12")
        let items = json["lessons"] as! [[String: Any]]
        #expect(items.map { $0["type"] as! String } == ["lesson", "break", "lesson", "break", "lesson"])
        #expect(items[0]["index"] as? String == "1")
        #expect(items[0]["icon"] as? String == "function")
        #expect(items[0]["start"] as? Int == Int(at(8, 0).timeIntervalSince1970 * 1000))
        #expect(items[1]["nextSubject"] as? String == "Fizika")
        #expect(items[1]["nextRoom"] as? String == "Fizika előadó")
        #expect(items[1]["start"] as? Int == Int(at(8, 45).timeIntervalSince1970 * 1000))
    }

    @Test func serverClientPaths() async throws {
        let t = MockTransport([(200, ""), (200, ""), (200, "")])
        let client = LiveServer(baseURL: URL(string: "https://la.example")!, transport: t)
        try await client.register(deviceID: "dev", pushToken: "tok", bundleID: "hu.radirapp.ios", color: "#2F6FEB")
        try await client.uploadSchedule(.init(deviceID: "dev", lessons: []))
        try await client.unregister(deviceID: "dev")
        #expect(t.requests.map { $0.url!.path } == ["/register", "/schedule", "/unregister"])
        let reg = try JSONSerialization.jsonObject(with: t.requests[0].httpBody!) as! [String: Any]
        #expect(reg["apns_token"] as? String == "tok" && reg["app_type"] as? String == "refilc")
        #expect((reg["settings"] as? [String: String])?["live_activity_color"] == "#2F6FEB")
    }
}
