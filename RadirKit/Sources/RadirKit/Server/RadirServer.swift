import Foundation

/// A Radír saját szervere (`refilc-live-server`): hírek, távoli config, témamegosztás.
public struct RadirServer: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport

    public init(baseURL: URL = LiveServer.production, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public struct NewsItem: Codable, Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let content: String
        public let link: String
        public let openLabel: String
        public let platform: String
        public let emergency: Bool
        public let expireDate: Date?
        public let specificAppID: String?

        enum CodingKeys: String, CodingKey {
            case id, title, content, link, platform, emergency
            case openLabel = "open_label", expireDate = "expire_date", specificAppID = "specific_app_id"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
            link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
            openLabel = try c.decodeIfPresent(String.self, forKey: .openLabel) ?? ""
            platform = try c.decodeIfPresent(String.self, forKey: .platform) ?? "all"
            emergency = try c.decodeIfPresent(Bool.self, forKey: .emergency) ?? false
            expireDate = adminDate(try c.decodeIfPresent(String.self, forKey: .expireDate))
            specificAppID = try c.decodeIfPresent(String.self, forKey: .specificAppID)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id); try c.encode(title, forKey: .title); try c.encode(content, forKey: .content)
            try c.encode(link, forKey: .link); try c.encode(openLabel, forKey: .openLabel); try c.encode(platform, forKey: .platform)
            try c.encode(emergency, forKey: .emergency); try c.encodeIfPresent(specificAppID, forKey: .specificAppID)
            try c.encodeIfPresent(expireDate.map { $0.formatted(.iso8601) }, forKey: .expireDate)
        }

        /// Csak az iOS-nek és ennek az appnak szóló hírek.
        public func isFor(bundleID: String) -> Bool {
            ["all", "ios"].contains(platform.lowercased()) && (specificAppID == nil || specificAppID == bundleID)
        }
    }

    /// Megosztott téma, a szerver (és a legacy) formátumában; a színek ARGB egészek.
    public struct SharedTheme: Codable, Identifiable, Hashable, Sendable {
        public var publicID: String
        public var isPublic: Bool
        public var nickname: String
        public var displayName: String
        public var backgroundColor: UInt32
        public var panelsColor: UInt32
        public var accentColor: UInt32
        public var iconColor: UInt32
        public var shadowEffect: Bool
        public var themeMode: String?
        public var fontFamily: String
        public var gradeColorsID: String?
        public var id: String { publicID }

        public init(isPublic: Bool, nickname: String, displayName: String, background: UInt32, panels: UInt32, accent: UInt32,
                    icon: UInt32, themeMode: String?, gradeColorsID: String?) {
            publicID = ""; self.isPublic = isPublic; self.nickname = nickname; self.displayName = displayName
            backgroundColor = background; panelsColor = panels; accentColor = accent; iconColor = icon
            shadowEffect = true; self.themeMode = themeMode; fontFamily = ""; self.gradeColorsID = gradeColorsID
        }

        enum CodingKeys: String, CodingKey {
            case publicID = "public_id", isPublic = "is_public", nickname, displayName = "display_name"
            case backgroundColor = "background_color", panelsColor = "panels_color", accentColor = "accent_color"
            case iconColor = "icon_color", shadowEffect = "shadow_effect", themeMode = "theme_mode", fontFamily = "font_family"
            case gradeColorsID = "grade_colors_id"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            publicID = try c.decodeIfPresent(String.self, forKey: .publicID) ?? ""
            isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
            nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
            displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
            backgroundColor = try c.decode(UInt32.self, forKey: .backgroundColor)
            panelsColor = try c.decode(UInt32.self, forKey: .panelsColor)
            accentColor = try c.decode(UInt32.self, forKey: .accentColor)
            iconColor = try c.decode(UInt32.self, forKey: .iconColor)
            shadowEffect = try c.decodeIfPresent(Bool.self, forKey: .shadowEffect) ?? true
            themeMode = try c.decodeIfPresent(String.self, forKey: .themeMode)
            fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? ""
            gradeColorsID = try c.decodeIfPresent(String.self, forKey: .gradeColorsID)
        }
    }

    public struct SharedGradeColors: Codable, Hashable, Sendable {
        public var publicID: String
        public var isPublic: Bool
        public var nickname: String
        /// 1-es … 5-ös
        public var colors: [UInt32]

        public init(isPublic: Bool, nickname: String, colors: [UInt32]) {
            publicID = ""; self.isPublic = isPublic; self.nickname = nickname; self.colors = colors
        }

        enum CodingKeys: String, CodingKey {
            case publicID = "public_id", isPublic = "is_public", nickname
            case one = "one_color", two = "two_color", three = "three_color", four = "four_color", five = "five_color"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            publicID = try c.decodeIfPresent(String.self, forKey: .publicID) ?? ""
            isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
            nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
            colors = try [.one, .two, .three, .four, .five].map { try c.decode(UInt32.self, forKey: $0) }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(isPublic, forKey: .isPublic); try c.encode(nickname, forKey: .nickname)
            for (k, v) in zip([CodingKeys.one, .two, .three, .four, .five], colors) { try c.encode(v, forKey: k) }
        }
    }

    public struct Mine: Decodable, Sendable {
        public let themes: [SharedTheme]
        public let gradeColors: [SharedGradeColors]
        enum CodingKeys: String, CodingKey { case themes, gradeColors = "grade_colors" }
    }

    // MARK: - Kérések

    private func request(_ path: String, method: String = "GET", body: Data? = nil, token: String? = nil) async throws -> Data {
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = method
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await transport.send(req)
        guard (200..<300).contains(res.statusCode) else { throw KretaError.http(res.statusCode) }
        return data
    }

    private func decode<T: Decodable>(_ t: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw KretaError.invalidResponse }
    }

    public func news(bundleID: String) async throws -> [NewsItem] {
        try decode([NewsItem].self, try await request("news")).filter { $0.isFor(bundleID: bundleID) }
    }

    /// Pl. `user_agent`: a KRÉTA user agent sablonja (vészfék, ha a KRÉTA letiltana egyet).
    public func config() async throws -> [String: String] {
        try decode([String: String].self, try await request("config"))
    }

    public func publicThemes() async throws -> [SharedTheme] { try decode([SharedTheme].self, try await request("themes")) }
    public func theme(_ id: String) async throws -> SharedTheme { try decode(SharedTheme.self, try await request("theme/\(id)")) }
    public func gradeColors(_ id: String) async throws -> SharedGradeColors {
        try decode(SharedGradeColors.self, try await request("theme/color/\(id)"))
    }

    /// Feltöltés KRÉTA tokennel; visszaadja az új azonosítót.
    public func upload(_ theme: SharedTheme, token: String) async throws -> String {
        try uploadedID(try await request("theme", method: "POST", body: JSONEncoder().encode(ThemeBody(theme)), token: token))
    }

    public func upload(_ colors: SharedGradeColors, token: String) async throws -> String {
        try uploadedID(try await request("theme/color", method: "POST", body: JSONEncoder().encode(colors), token: token))
    }

    public func mine(token: String) async throws -> Mine { try decode(Mine.self, try await request("themes/mine", token: token)) }

    public func deleteTheme(_ id: String, token: String) async throws { _ = try await request("theme/\(id)", method: "DELETE", token: token) }

    private func uploadedID(_ data: Data) throws -> String {
        try decode([String: String].self, data)["public_id"] ?? { throw KretaError.invalidResponse }()
    }

    /// A feltöltéskor a `public_id`-t a szerver adja, ezért nem küldjük.
    private struct ThemeBody: Encodable {
        let t: SharedTheme
        init(_ t: SharedTheme) { self.t = t }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: SharedTheme.CodingKeys.self)
            try c.encode(t.isPublic, forKey: .isPublic); try c.encode(t.nickname, forKey: .nickname)
            try c.encode(t.displayName, forKey: .displayName); try c.encode(t.backgroundColor, forKey: .backgroundColor)
            try c.encode(t.panelsColor, forKey: .panelsColor); try c.encode(t.accentColor, forKey: .accentColor)
            try c.encode(t.iconColor, forKey: .iconColor); try c.encode(t.shadowEffect, forKey: .shadowEffect)
            try c.encode(t.themeMode, forKey: .themeMode); try c.encode(t.fontFamily, forKey: .fontFamily)
            try c.encode(t.gradeColorsID, forKey: .gradeColorsID)
        }
    }
}

extension KretaSession {
    /// A KRÉTA access token a saját szerver azonosításához (témafeltöltés).
    public func accessToken() async throws -> String { try await validAccessTokenForServer() }
}
