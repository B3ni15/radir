import Foundation

public enum Kreta {
    public static let idp = URL(string: "https://idp.e-kreta.hu")!
    public static let clientID = "kreta-ellenorzo-student-mobile-ios"
    public static let redirectURI = "https://mobil.e-kreta.hu/ellenorzo-student/prod/oauthredirect"
    public static let scope = "openid email offline_access kreta-ellenorzo-webapi.public kreta-eugyintezes-webapi.public kreta-fileservice-webapi.public kreta-mobile-global-webapi.public kreta-dkt-webapi.public kreta-ier-webapi.public"
    /// A token végpont ezt a user agentet várja (legacy szerint).
    public static let tokenUserAgent = "eKretaStudent/264745 CFNetwork/1494.0.7 Darwin/23.4.0"

    public static func base(_ instituteCode: String) -> URL {
        URL(string: "https://\(instituteCode).e-kreta.hu")!
    }

    public static func studentURL(_ instituteCode: String) -> URL {
        base(instituteCode).appending(path: "ellenorzo/V3/Sajat/TanuloAdatlap")
    }
}
