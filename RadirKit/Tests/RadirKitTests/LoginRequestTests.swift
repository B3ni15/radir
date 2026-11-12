import Foundation
import Testing
@testable import RadirKit

@Suite struct LoginRequestTests {
    @Test func pkceChallengeIsBase64URLSHA256() {
        // openssl dgst -sha256 -binary | base64, URL-safe, padding nélkül
        let p = PKCE(verifier: "dBjftJeZ4CVP-mJ92K9oDwWCXy3lVA1J71tuPYlRMf8")
        #expect(p.challenge == "Rvn3sx4kKTmZ4vgKwKwJnTme31clfJeLb7_VokDXMic")
    }

    @Test func generatedVerifierShape() {
        let a = PKCE.generate(), b = PKCE.generate()
        #expect((43...128).contains(a.verifier.count))
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect(a.verifier.unicodeScalars.allSatisfy(allowed.contains))
        #expect(a.verifier != b.verifier)
    }

    @Test func authorizeURL() throws {
        let r = LoginRequest.make()
        let items = try #require(URLComponents(url: r.authorizeURL, resolvingAgainstBaseURL: false)?.queryItems)
        let q = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(r.authorizeURL.absoluteString.hasPrefix("https://idp.e-kreta.hu/connect/authorize?"))
        #expect(q["client_id"] == "kreta-ellenorzo-student-mobile-ios")
        #expect(q["redirect_uri"] == "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect")
        #expect(q["response_type"] == "code")
        #expect(q["code_challenge_method"] == "S256")
        #expect(q["prompt"] == "login")
        #expect(q["code_challenge"] == r.pkce.challenge)
        #expect(q["state"] == r.state)
        #expect(q["nonce"] == r.nonce)
        #expect(q["scope"] == "openid email offline_access kreta-ellenorzo-webapi.public kreta-eugyintezes-webapi.public kreta-fileservice-webapi.public kreta-mobile-global-webapi.public kreta-dkt-webapi.public kreta-ier-webapi.public")
    }

    @Test func codeFromRedirect() {
        let r = LoginRequest.make()
        let ok = URL(string: "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=ABC&state=\(r.state)")!
        #expect(r.code(from: ok) == "ABC")
    }

    @Test func redirectWithoutCodeIsIgnored() {
        let r = LoginRequest.make()
        #expect(r.code(from: URL(string: "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?error=access_denied&state=\(r.state)")!) == nil)
        #expect(r.code(from: URL(string: "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=&state=\(r.state)")!) == nil)
    }

    @Test func foreignHostIsIgnored() {
        let r = LoginRequest.make()
        #expect(r.code(from: URL(string: "https://evil.example/ellenorzo-student/prod/oauthredirect?code=x&state=\(r.state)")!) == nil)
        #expect(r.code(from: URL(string: "https://mobil.e-kreta.hu/other?code=x&state=\(r.state)")!) == nil)
    }

    @Test func stateMismatchIsIgnored() {
        let r = LoginRequest.make()
        #expect(r.code(from: URL(string: "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect?code=x&state=other")!) == nil)
    }
}
