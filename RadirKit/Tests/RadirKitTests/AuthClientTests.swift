import Foundation
import Testing
@testable import RadirKit

@Suite struct AuthClientTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func exchangeSendsPKCEForm() async throws {
        let t = MockTransport([(200, tokenJSON(expiresIn: 1800))])
        let pkce = PKCE(verifier: "v".padding(toLength: 43, withPad: "v", startingAt: 0))
        let tokens = try await AuthClient(transport: t, now: { now }).exchange(code: "C0DE", pkce: pkce)
        #expect(tokens == TokenSet(accessToken: "acc", refreshToken: "ref", expiresAt: now.addingTimeInterval(1800)))
        let req = t.requests[0]
        #expect(req.url?.absoluteString == "https://idp.e-kreta.hu/connect/token")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "User-Agent") == "eKretaStudent/264745 CFNetwork/1494.0.7 Darwin/23.4.0")
        #expect(t.formBody(0) == [
            "code": "C0DE", "code_verifier": pkce.verifier,
            "redirect_uri": "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect",
            "client_id": "kreta-ellenorzo-student-mobile-ios", "grant_type": "authorization_code",
        ])
    }

    @Test func refreshSendsLegacyForm() async throws {
        let t = MockTransport([(200, tokenJSON(access: "a2", refresh: "r2"))])
        let tokens = try await AuthClient(transport: t, now: { now }).refresh("r1", instituteCode: "klik1")
        #expect(tokens.accessToken == "a2" && tokens.refreshToken == "r2")
        #expect(t.formBody(0) == [
            "refresh_token": "r1", "institute_code": "klik1", "client_id": "kreta-ellenorzo-student-mobile-ios",
            "grant_type": "refresh_token", "refresh_user_data": "false",
        ])
    }

    @Test func refreshInvalidGrantThrowsReloginRequired() async {
        let t = MockTransport([(400, #"{"error":"invalid_grant"}"#)])
        await #expect(throws: KretaError.reloginRequired) {
            try await AuthClient(transport: t).refresh("r", instituteCode: "x")
        }
    }

    @Test func serverErrorIsHTTPError() async {
        let t = MockTransport([(500, "")])
        await #expect(throws: KretaError.http(500)) {
            try await AuthClient(transport: t).refresh("r", instituteCode: "x")
        }
    }

    @Test func tokenExpiry() {
        let t = TokenSet(accessToken: "a", refreshToken: "r", expiresAt: now)
        #expect(t.isExpired(now: now.addingTimeInterval(-29)))
        #expect(!t.isExpired(now: now.addingTimeInterval(-31)))
    }

    @Test func jwtClaims() throws {
        let jwt = fakeJWT(["kreta:institute_code": "klik035046001", "kreta:user_name": "72012345678", "role": "Tanulo", "name": "Teszt Elek"])
        let c = try JWTClaims(accessToken: jwt)
        #expect(c.instituteCode == "klik035046001")
        #expect(c.userName == "72012345678")
        #expect(c.role == .student)
        #expect(c.name == "Teszt Elek")
        #expect(throws: KretaError.invalidResponse) { try JWTClaims(accessToken: "nem.jwt") }
    }
}
