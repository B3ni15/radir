public enum UserAgent {
    /// A legacy `/config` `user_agent` sablonja: `$0` = appverzió, `$1` = platform, `$2` = build.
    public static func api(template: String = "hu.ekreta.student/$0/$1/$2", appVersion: String) -> String {
        template
            .replacingOccurrences(of: "$0", with: appVersion)
            .replacingOccurrences(of: "$1", with: "iOS")
            .replacingOccurrences(of: "$2", with: "0")
    }
}
