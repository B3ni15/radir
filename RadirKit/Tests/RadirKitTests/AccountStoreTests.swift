import Foundation
import Testing
@testable import RadirKit

@Suite struct AccountStoreTests {
    let file = FileManager.default.temporaryDirectory.appending(path: "accounts-\(UUID().uuidString).json")
    let tokens = InMemoryTokenStore()

    func account(_ user: String, institute: String = "klik1") -> Account {
        Account(userName: user, instituteCode: institute, role: .student,
                student: Student(uid: user, name: "Diák \(user)", instituteCode: institute, schoolName: "Isk", birthDate: nil, parents: [], address: nil))
    }

    func tok(_ a: String) -> TokenSet { TokenSet(accessToken: a, refreshToken: "r", expiresAt: .distantFuture) }

    @Test func persistsAccountsAndSelection() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.upsert(account("b"), tokens: tok("2"))
        let reloaded = AccountStore(fileURL: file, tokens: tokens)
        #expect(reloaded.accounts.map(\.id) == ["klik1/a", "klik1/b"])
        #expect(reloaded.selectedID == "klik1/b")
        #expect(try tokens.tokens(for: "klik1/a")?.accessToken == "1")
    }

    @Test func sameUserLoginReplacesAccount() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.markNeedsRelogin(id: "klik1/a")
        try s.upsert(account("a"), tokens: tok("2"))
        #expect(s.accounts.count == 1)
        #expect(s.accounts[0].needsRelogin == false)
        #expect(try tokens.tokens(for: "klik1/a")?.accessToken == "2")
    }

    @Test func removeDeletesTokenAndMovesSelection() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.upsert(account("b"), tokens: tok("2"))
        try s.remove(id: "klik1/b")
        #expect(s.selectedID == "klik1/a")
        #expect(try tokens.tokens(for: "klik1/b") == nil)
        try s.remove(id: "klik1/a")
        #expect(s.selectedID == nil && s.accounts.isEmpty)
    }

    /// Az utolsó fiók törlése is elmentődik: újraindítás után a bejelentkezés jön, nem a régi fiók.
    @Test func lastAccountRemovalPersists() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.remove(id: "klik1/a")
        let reloaded = AccountStore(fileURL: file, tokens: tokens)
        #expect(reloaded.accounts.isEmpty)
        #expect(reloaded.selectedID == nil)
    }

    /// Ha a token törlése hibára fut (pl. Keychain), a fiók db-ban akkor is el kell tűnnie a telefonról.
    @Test func removeIgnoresTokenDeleteFailure() throws {
        let failing = DeleteFailingTokenStore()
        let s = AccountStore(fileURL: file, tokens: failing)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.remove(id: "klik1/a")
        #expect(s.accounts.isEmpty)
        #expect(s.selectedID == nil)
        #expect(AccountStore(fileURL: file, tokens: failing).accounts.isEmpty)
    }

    @Test func needsReloginSurvivesReload() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(account("a"), tokens: tok("1"))
        try s.markNeedsRelogin(id: "klik1/a")
        #expect(AccountStore(fileURL: file, tokens: tokens).accounts[0].needsRelogin)
    }

    @Test func demoAccountHasNoToken() throws {
        let s = AccountStore(fileURL: file, tokens: tokens)
        try s.upsert(Demo.account, tokens: nil)
        #expect(s.accounts[0].isDemo)
        #expect(try tokens.tokens(for: Demo.account.id) == nil)
    }

    @Test func corruptFileStartsEmpty() throws {
        try Data("nem json".utf8).write(to: file)
        #expect(AccountStore(fileURL: file, tokens: tokens).accounts.isEmpty)
    }
}

/// Csak a `delete` hibázik: a tokent a fiók törlésének nem szabad kockáztatnia.
final class DeleteFailingTokenStore: TokenStore, @unchecked Sendable {
    private let inner = InMemoryTokenStore()
    func tokens(for id: String) throws -> TokenSet? { try inner.tokens(for: id) }
    func save(_ tokens: TokenSet, for id: String) throws { try inner.save(tokens, for: id) }
    func delete(id: String) throws { throw TokenStoreError.keychain(-34018) }
}
