import Foundation
import Testing
@testable import RadirKit

@Suite struct MessagingTests {
    func session(_ t: MockTransport) -> KretaSession {
        KretaSession(instituteCode: "klik1", tokens: TokenSet(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture),
                     auth: AuthClient(transport: t), transport: t, userAgent: "UA", onTokensChanged: { _ in })
    }

    @Test func listDecodes() throws {
        let m = try KretaMessage.decodeList(fixture("Postafiok"), box: .inbox)
        #expect(m.map(\.id) == [111, 112])
        #expect(m[0].subject == "Holnapi dolgozat" && m[0].sender == "Nagy Katalin" && !m[0].isRead)
        #expect(m[0].date == budapest(2026, 11, 11, 9, 30))
        #expect(m[1].isRead && m[1].text.isEmpty)
        #expect(m[0].hasAttachments && !m[1].hasAttachments)
    }

    @Test func detailDecodes() throws {
        let m = try KretaMessage.decodeDetail(fixture("Uzenet"), box: .inbox)
        #expect(m.sender == "Nagy Katalin")
        #expect(m.plainText == "Kedves Diákok!\nHolnap dolgozat.")
        #expect(m.recipients == ["10.A"])
        #expect(m.attachments == [MessageAttachment(id: 777, name: "feladatok.pdf")])
    }

    @Test func fetchesBoxFromAdminHost() async throws {
        let t = MockTransport([(200, String(decoding: try fixture("Postafiok"), as: UTF8.self))])
        let list = try await MessagingService().list(.sent, session: session(t))
        #expect(list.count == 2 && list.allSatisfy { $0.box == .sent })
        #expect(t.requests[0].url?.absoluteString == "https://eugyintezes.e-kreta.hu/api/v1/kommunikacio/postaladaelemek/elkuldott")
    }

    @Test func recipientsFromCategoriesAndStaff() async throws {
        let t = MockTransport([
            (200, #"[{"azonosito":1,"kod":"TANAR","leiras":"Tanár","nev":"Tanár","rovidNev":"T"},{"azonosito":2,"kod":"IGAZGATOSAG","leiras":"Igazgatóság","nev":"Igazgatóság","rovidNev":"I"},{"azonosito":3,"kod":"OSZTALYFONOK","nev":"Ofő"}]"#),
            (200, #"[{"kretaAzonosito":10,"nev":"Nagy Katalin"},{"kretaAzonosito":11,"nev":"Tóth László"}]"#),
            (200, #"[{"kretaAzonosito":20,"nev":"Kiss Igazgató"}]"#),
        ])
        let r = try await MessagingService().recipients(session: session(t))
        #expect(r.map(\.name) == ["Kiss Igazgató", "Nagy Katalin", "Tóth László"])
        #expect(r.first { $0.name == "Nagy Katalin" }?.type.code == "TANAR")
        #expect(t.requests.map { $0.url!.path } == ["/api/v1/adatszotarak/cimzetttipusok", "/api/v1/kreta/alkalmazottak/tanar", "/api/v1/kreta/alkalmazottak/igazgatosag"])
    }

    @Test func sendBuildsLegacyBody() async throws {
        let t = MockTransport([(200, "{}")])
        let teacher = MessageRecipient(kretaID: 10, name: "Nagy Katalin",
                                       type: .init(id: 1, code: "TANAR", description: "Tanár", name: "Tanár", shortName: "T"))
        try await MessagingService().send(to: [teacher], subject: "Kérdés", text: "Szia!", senderName: "Teszt Elek",
                                          isParent: false, session: session(t))
        let req = t.requests[0]
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://eugyintezes.e-kreta.hu/api/v1/kommunikacio/uzenetek")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        #expect(body["targy"] as? String == "Kérdés" && body["szoveg"] as? String == "Szia!")
        #expect(body["feladoTitulus"] as? String == "Diák")
        let r = (body["cimzettLista"] as! [[String: Any]])[0]
        #expect(r["kretaAzonosito"] as? Int == 10 && (r["tipus"] as? [String: Any])?["kod"] as? String == "TANAR")
    }

    @Test func sendPermissionError() async {
        let t = MockTransport([(200, #"{"hibakod":"UzenetKuldesEngedelyRule"}"#)])
        let teacher = MessageRecipient(kretaID: 10, name: "X", type: .init(id: 1, code: "TANAR", description: "", name: "", shortName: ""))
        await #expect(throws: MessagingError.notAllowed) {
            try await MessagingService().send(to: [teacher], subject: "a", text: "b", senderName: "c", isParent: false, session: session(t))
        }
    }

    @Test func wallItems() throws {
        let w = try WallItem.decodeKreta(fixture("FaliujsagElemek"))[0]
        #expect(w.title == "Szünet" && w.plainText == "Az őszi szünet okt. 26-tól tart.")
        #expect(w.isValid(at: budapest(2026, 11, 12)) && !w.isValid(at: budapest(2026, 12, 12)))
    }
}
