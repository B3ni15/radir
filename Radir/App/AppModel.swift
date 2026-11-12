import Foundation
import Observation
import RadirKit

/// Fiókok, belépés, kijelentkezés és a fiókonkénti KRÉTA munkamenetek.
@Observable
final class AppModel {
    private let store: AccountStore
    private let auth: AuthClient
    private let transport: any HTTPTransport
    private var sessions: [String: KretaSession] = [:]

    private(set) var accounts: [Account] = []
    /// A kiválasztott fül, és egy óra, amit az Órarend fülön meg kell nyitni (pl. a kezdőlapról).
    var tab: AppTab = .home
    var openLesson: Lesson?

    let prefs = Preferences()

    /// A kiválasztott fiók átnevezései (tantárgyak, tanárok).
    var renaming: Renaming { notebook.notebook.renaming }

    /// Átnevezés után: a tárolt adatok újra betöltődnek az új nevekkel.
    func reloadData() {
        grades = GradesModel()
        timetable = TimetableModel()
        school = SchoolModel()
    }

    func show(_ lesson: Lesson) {
        openLesson = lesson
        tab = .timetable
    }
    private(set) var current: Account? {
        didSet {
            if oldValue?.id != current?.id {
                grades = GradesModel()
                timetable = TimetableModel()
                school = SchoolModel()
                notebook = NotebookModel()
                messages = MessagesModel()
            }
        }
    }
    /// A kiválasztott fiók adatai; fiókváltáskor újraindulnak.
    private(set) var grades = GradesModel()
    private(set) var timetable = TimetableModel()
    private(set) var school = SchoolModel()
    private(set) var notebook = NotebookModel()
    private(set) var messages = MessagesModel()
    let liveActivity = LiveActivityController()
    let cache = AccountCache(root: URL.applicationSupportDirectory.appending(path: "cache"))

    init(store: AccountStore = AppModel.defaultStore(), transport: any HTTPTransport = URLSessionTransport()) {
        self.store = store
        self.transport = transport
        auth = AuthClient(transport: transport)
        sync()
        tab = prefs.startTab
    }

    static func defaultStore() -> AccountStore {
        let dir = URL.applicationSupportDirectory
        return AccountStore(fileURL: dir.appending(path: "accounts.json"), tokens: KeychainTokenStore())
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Webes belépés után: kódcsere, a diák adatai, fiók mentése.
    func completeLogin(code: String, request: LoginRequest) async throws {
        let tokens = try await auth.exchange(code: code, pkce: request.pkce)
        let claims = try JWTClaims(accessToken: tokens.accessToken)
        let id = Account.id(instituteCode: claims.instituteCode, userName: claims.userName)
        let session = makeSession(id: id, instituteCode: claims.instituteCode, tokens: tokens)
        let student = try await session.get(Student.self, from: Kreta.studentURL(claims.instituteCode))
        let account = Account(userName: claims.userName, instituteCode: claims.instituteCode, role: claims.role, student: student)
        try store.upsert(account, tokens: tokens)
        sessions[account.id] = session
        sync()
    }

    func startDemo() {
        try? store.upsert(Demo.account, tokens: nil)
        sync()
    }

    func select(_ id: String) {
        store.selectedID = id
        sync()
    }

    /// A refresh tokent visszavonja a KRÉTA-nál; ha ez nem sikerül, helyben akkor is töröl.
    func logout(_ id: String) async {
        if let tokens = try? store.tokens.tokens(for: id) {
            try? await auth.revoke(tokens.refreshToken)
        }
        try? store.remove(id: id)
        cache.removeAll(for: id)
        sessions[id] = nil
        sync()
    }

    /// A KRÉTA-kérésekhez. Demó fióknál és hiányzó tokennél nil.
    func session(for account: Account) -> KretaSession? {
        if let s = sessions[account.id] { return s }
        guard !account.isDemo, let tokens = try? store.tokens.tokens(for: account.id) else { return nil }
        let s = makeSession(id: account.id, instituteCode: account.instituteCode, tokens: tokens)
        sessions[account.id] = s
        return s
    }

    /// Hívja minden betöltő, ha a munkamenet `reloginRequired` hibát dob.
    func markNeedsRelogin(_ id: String) {
        try? store.markNeedsRelogin(id: id)
        sessions[id] = nil
        sync()
    }

    private func makeSession(id: String, instituteCode: String, tokens: TokenSet) -> KretaSession {
        let tokenStore = store.tokens
        return KretaSession(instituteCode: instituteCode, tokens: tokens, auth: auth, transport: transport,
                            userAgent: UserAgent.api(appVersion: Self.appVersion),
                            onTokensChanged: { try? tokenStore.save($0, for: id) })
    }

    private func sync() {
        accounts = store.accounts
        current = store.selected ?? store.accounts.last
        notebook.open(self)
    }
}

extension Error {
    /// Megszakított kérés: nem hiba, nem kell kiírni.
    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
