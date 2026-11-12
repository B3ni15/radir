import Foundation
import Testing
@testable import RadirKit

@Suite struct RadirServerTests {
    let base = URL(string: "https://srv.example")!

    @Test func newsFilteredForIOSAndApp() async throws {
        let t = MockTransport([(200, #"""
        [{"id":"1","title":"Mindenkinek","content":"x","link":"","open_label":"","platform":"all","emergency":true,"expire_date":"2026-12-01T00:00:00","app_versions":null,"specific_app_id":null},
         {"id":"2","title":"Android","content":"","link":"","open_label":"","platform":"android","emergency":false,"expire_date":"2026-12-01T00:00:00","app_versions":null,"specific_app_id":null},
         {"id":"3","title":"Firka","content":"","link":"","open_label":"","platform":"ios","emergency":false,"expire_date":"2026-12-01T00:00:00","app_versions":null,"specific_app_id":"app.firka"}]
        """#)])
        let news = try await RadirServer(baseURL: base, transport: t).news(bundleID: "hu.radirapp.ios")
        #expect(news.map(\.id) == ["1"] && news[0].emergency)
        #expect(news[0].expireDate == budapest(2026, 12, 1))
        #expect(t.requests[0].url?.absoluteString == "https://srv.example/news")
    }

    @Test func uploadThemeSendsLegacyFieldsAndToken() async throws {
        let t = MockTransport([(201, #"{"public_id":"AbC123xyz789"}"#)])
        let theme = RadirServer.SharedTheme(isPublic: true, nickname: "Beni", displayName: "Kék", background: 0xFF000000,
                                            panels: 0xFF111111, accent: 0xFF2F6FEB, icon: 0xFFFFFFFF, themeMode: "dark", gradeColorsID: nil)
        let id = try await RadirServer(baseURL: base, transport: t).upload(theme, token: "tok")
        #expect(id == "AbC123xyz789")
        let req = t.requests[0]
        #expect(req.httpMethod == "POST" && req.url?.path == "/theme" && req.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        #expect(body["public_id"] == nil)
        #expect(body["accent_color"] as? UInt32 == 0xFF2F6FEB && body["theme_mode"] as? String == "dark" && body["is_public"] as? Bool == true)
    }

    @Test func themeAndGradeColorsDecode() async throws {
        let t = MockTransport([
            (200, #"{"public_id":"x","is_public":false,"nickname":"N","display_name":"D","background_color":1,"panels_color":2,"accent_color":3,"icon_color":4,"shadow_effect":true,"theme_mode":null,"font_family":"","grade_colors_id":"g"}"#),
            (200, #"{"public_id":"g","is_public":false,"nickname":"N","five_color":5,"four_color":4,"three_color":3,"two_color":2,"one_color":1}"#),
        ])
        let s = RadirServer(baseURL: base, transport: t)
        let th = try await s.theme("x")
        #expect(th.accentColor == 3 && th.gradeColorsID == "g" && th.themeMode == nil)
        #expect(try await s.gradeColors("g").colors == [1, 2, 3, 4, 5])
    }

    @Test func missingThemeIs404() async {
        let t = MockTransport([(404, "")])
        await #expect(throws: KretaError.http(404)) { try await RadirServer(baseURL: base, transport: t).theme("nincs") }
    }
}
