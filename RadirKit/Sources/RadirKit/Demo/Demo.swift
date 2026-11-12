/// Demó fiók KRÉTA nélkül: kipróbáláshoz és az App Store review-hoz.
public enum Demo {
    public static let instituteCode = "radir-demo"

    public static let account = Account(
        userName: "demo", instituteCode: instituteCode, role: .student,
        student: Student(uid: "demo", name: "Demó Diák", instituteCode: instituteCode,
                         schoolName: "Radír Demó Gimnázium", birthDate: nil,
                         parents: ["Demó Szülő"], address: "1117 Budapest, Demó utca 1."))
}
