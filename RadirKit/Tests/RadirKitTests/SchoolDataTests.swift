import Foundation
import Testing
@testable import RadirKit

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct SchoolDataTests {
    @Test func absences() throws {
        let a = try Absence.decodeKreta(fixture("Mulasztasok"))
        #expect(a[0].kind == .absence && a[0].state == .excused && a[0].teacher == "Nagy Katalin")
        #expect(a[0].justification == "Orvosi igazolás" && a[0].lessonIndex == 1)
        #expect(a[0].lessonStart == budapest(2026, 11, 10, 8, 0))
        #expect(a[0].date == budapest(2026, 11, 10))
        #expect(a[1].kind == .late && a[1].delayMinutes == 7 && a[1].state == .unexcused)
        #expect(a[2].state == .pending && a[2].lessonStart == nil)
    }

    @Test func absenceSummary() throws {
        let s = AbsenceSummary(try Absence.decodeKreta(fixture("Mulasztasok")))
        #expect(s.excused == 1 && s.unexcused == 0 && s.pending == 1)
        #expect(s.lateCount == 1 && s.lateMinutes == 7)
        #expect(s.bySubject.map(\.subject.id) == ["matek", "fizika"])
        #expect(s.bySubject[0].absences == 2)
    }

    @Test func homework() throws {
        let h = try Homework.decodeKreta(fixture("HaziFeladatok"))
        #expect(h[0].plainText == "Tankönyv 45. oldal 1–3. feladat")
        #expect(h[0].deadline == budapest(2026, 11, 13))
        #expect(h[0].attachments == [HomeworkAttachment(id: "c1", name: "feladatlap.pdf")])
        #expect(h[0].byTeacher && h[0].teacher == "Nagy Katalin")
        #expect(h[1].text.isEmpty && h[1].needsDetails)
    }

    @Test func exams() throws {
        let e = try Exam.decodeKreta(fixture("BejelentettSzamonkeresek"))[0]
        #expect(e.date == budapest(2026, 11, 18) && e.announced == budapest(2026, 11, 5, 11, 0))
        #expect(e.topic == "Másodfokú egyenletek" && e.mode == "Írásbeli röpdolgozat" && e.lessonIndex == 3)
    }

    @Test func schoolNotes() throws {
        let n = try SchoolNote.decodeKreta(fixture("Feljegyzesek"))[0]
        #expect(n.title == "Dicséret" && n.content == "Kiváló szavalóverseny-szereplés.\nGratulálunk!")
        #expect(n.kind == "Dicséret" && n.teacher == "Kovács Mária")
    }

    @Test func serviceFetchesHomeworkDetailsWhenTextMissing() async throws {
        let t = MockTransport([
            (200, String(decoding: try fixture("HaziFeladatok"), as: UTF8.self)),
            (200, #"{"Uid":"h2","Szoveg":"Workbook p. 12","HataridoDatuma":"2026-11-16T23:00:00Z","Tantargy":{"Uid":"angol","Nev":"Angol nyelv"}}"#),
        ])
        let s = KretaSession(instituteCode: "klik1", tokens: TokenSet(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture),
                             auth: AuthClient(transport: t), transport: t, userAgent: "UA", onTokensChanged: { _ in })
        let hw = try await SchoolDataService().homework(session: s, instituteCode: "klik1", from: budapest(2026, 11, 1))
        #expect(hw.map(\.plainText) == ["Tankönyv 45. oldal 1–3. feladat", "Workbook p. 12"])
        #expect(t.requests[0].url?.absoluteString == "https://klik1.e-kreta.hu/ellenorzo/V3/Sajat/HaziFeladatok?datumTol=2026-11-01")
        #expect(t.requests[1].url?.path == "/ellenorzo/V3/Sajat/HaziFeladatok/h2")
    }
}
