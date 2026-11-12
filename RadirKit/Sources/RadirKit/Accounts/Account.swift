public struct Account: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var userName: String
    public var instituteCode: String
    public var role: Role
    public var student: Student
    /// A refresh token lejárt: a fiók megmarad, de újra be kell lépni.
    public var needsRelogin: Bool

    public init(userName: String, instituteCode: String, role: Role, student: Student, needsRelogin: Bool = false) {
        id = Account.id(instituteCode: instituteCode, userName: userName)
        self.userName = userName
        self.instituteCode = instituteCode
        self.role = role
        self.student = student
        self.needsRelogin = needsRelogin
    }

    public static func id(instituteCode: String, userName: String) -> String { "\(instituteCode)/\(userName)" }

    public var isDemo: Bool { instituteCode == Demo.instituteCode }
}
