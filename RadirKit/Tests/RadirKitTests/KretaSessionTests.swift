import Foundation
import Testing
@testable import RadirKit

actor Box<T: Sendable> {
    var values: [T] = []
    func add(_ v: T) { values.append(v) }
}

@Suite struct KretaSessionTests {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let url = URL(string: "https://klik1.e-kreta.hu/ellenorzo/V3/Sajat/TanuloAdatlap")!

    func session(_ t: MockTransport, expired: Bool = false, changed: Box<TokenSet> = Box()) -> KretaSession {
        let tokens = TokenSet(accessToken: "old", refreshToken: "r1", expiresAt: expired ? now : now.addingTimeInterval(3600))
        let now = self.now
        return KretaSession(instituteCode: "klik1", tokens: tokens, auth: AuthClient(transport: t, now: { now }),
                            transport: t, userAgent: "UA/1", now: { now }, onTokensChanged: { await changed.add($0) })
    }

    @Test func addsAuthAndUserAgent() async throws {
        let t = MockTransport([(200, "{}")])
        _ = try await session(t).data(for: url)
        #expect(t.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old")
        #expect(t.requests[0].value(forHTTPHeaderField: "User-Agent") == "UA/1")
    }

    @Test func expiredTokenRefreshesFirst() async throws {
        let t = MockTransport([(200, tokenJSON(access: "new")), (200, "{}")])
        let changed = Box<TokenSet>()
        _ = try await session(t, expired: true, changed: changed).data(for: url)
        #expect(t.requests.count == 2)
        #expect(t.requests[0].url?.path == "/connect/token")
        #expect(t.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new")
        #expect(await changed.values.map(\.accessToken) == ["new"])
    }

    @Test func unauthorizedRetriesOnce() async throws {
        let t = MockTransport([(401, ""), (200, tokenJSON(access: "new")), (200, #"{"ok":true}"#)])
        let data = try await session(t).data(for: url)
        #expect(String(decoding: data, as: UTF8.self) == #"{"ok":true}"#)
        #expect(t.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test func secondUnauthorizedFails() async {
        let t = MockTransport([(401, ""), (200, tokenJSON(access: "new")), (401, "")])
        await #expect(throws: KretaError.http(401)) { try await session(t).data(for: url) }
    }

    @Test func concurrentRequestsRefreshOnce() async throws {
        let t = MockTransport([(200, tokenJSON(access: "new")), (200, "{}"), (200, "{}")])
        t.delay = .milliseconds(50)
        let s = session(t, expired: true)
        async let a = s.data(for: url)
        async let b = s.data(for: url)
        _ = try await (a, b)
        #expect(t.requests.filter { $0.url?.path == "/connect/token" }.count == 1)
        #expect(t.requests.count == 3)
    }

    @Test func reloginRequiredPropagates() async {
        let t = MockTransport([(400, #"{"error":"invalid_grant"}"#)])
        await #expect(throws: KretaError.reloginRequired) { try await session(t, expired: true).data(for: url) }
    }

    @Test func decodesJSON() async throws {
        let t = MockTransport([(200, #"{"Uid":"1","Nev":"A","IntezmenyAzonosito":"k","IntezmenyNev":"I"}"#)])
        let s = try await session(t).get(Student.self, from: url)
        #expect(s.name == "A")
    }

    @Test func userAgentTemplate() {
        #expect(UserAgent.api(appVersion: "0.1.0") == "hu.ekreta.student/0.1.0/iOS/0")
        #expect(UserAgent.api(template: "x/$1-$0", appVersion: "2") == "x/iOS-2")
    }
}
