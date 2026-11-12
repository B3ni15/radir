import RadirKit
import SwiftUI

/// Év végi összefoglaló a Firka (reFilc) „summary” képernyőinek mintájára: ugyanaz a kék–lila háttér,
/// „Jó éved volt, …!” fejléc, jobbról becsúszó sorok, számrács, és a felfedhető „személyiség”.
/// Csak bizonyítványosztás után nyitható meg (`AppModel.summaryBook`).
struct SummaryView: View {
    let book: GradeBook
    let absences: [Absence]
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var revealed = false
    @State private var revealedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = YearSummary(book: book, absences: absences)
        let pages = StoryPage.pages(for: s)
        let current = pages[min(page, pages.count - 1)]
        let isLast = page == pages.count - 1
        ZStack {
            SummaryBackground()

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule().fill(.white.opacity(i <= page ? 0.9 : 0.25)).frame(height: 3)
                        }
                    }
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.m(.subheadline, .bold)).frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Bezárás")
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jó éved volt, \(firstName)!").font(.custom("Montserrat-ExtraBold", size: 26, relativeTo: .title))
                        Text(current.title).font(.custom("Montserrat-Bold", size: 21, relativeTo: .title2)).opacity(0.92)
                            .id(current)
                            .transition(.push(from: .trailing))
                    }
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Button { isLast ? dismiss() : next(pages) } label: {
                        Image(systemName: isLast ? "checkmark" : "arrow.right")
                            .font(.m(.title3, .bold))
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel(isLast ? "Kész" : "Tovább")
                }

                StoryPageView(page: current, summary: s, book: book, revealed: revealed)
                    .id(current)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(.rect)
                    .onTapGesture(coordinateSpace: .local) { _ in next(pages) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)

            if let revealedAt, !reduceMotion { Confetti(start: revealedAt).ignoresSafeArea() }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width > 60, page > 0 { withAnimation(.snappy) { page -= 1 } }
            else if v.translation.width < -60 { next(pages) }
            else if v.translation.height > 120 { dismiss() }
        })
    }

    private var firstName: String {
        app.current?.student.name.split(separator: " ").last.map(String.init) ?? ""
    }

    private func next(_ pages: [StoryPage]) {
        if pages[page] == .personality, !revealed {
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) { revealed = true }
            revealedAt = .now
            return
        }
        guard page < pages.count - 1 else { return }
        withAnimation(.snappy(duration: 0.45)) { page += 1 }
    }

    static func describe(_ p: YearSummary.Personality) -> (String, String, String) {
        switch p {
        case .geek: ("🤓", String(localized: "Okostojás"), String(localized: "Szinte minden tantárgyból kiváló vagy. Csak így tovább!"))
        case .fallible: ("📉", String(localized: "Nehéz év"), String(localized: "Több egyes is becsúszott. Jövőre jobb lesz!"))
        case .healthy: ("💪", String(localized: "Vasegészség"), String(localized: "Alig hiányoztál egész évben."))
        case .quitter: ("🏃", String(localized: "Lógós"), String(localized: "Sok az igazolatlan hiányzás. Vigyázz rá!"))
        case .late: ("⌛", String(localized: "Késős"), String(localized: "A busz mindig pont akkor késik, igaz?"))
        case .sick: ("🤒", String(localized: "Sokat beteg"), String(localized: "Sokat hiányoztál. Jobbulást!"))
        case .acceptable: ("🤏", String(localized: "Átmenő"), String(localized: "Sok a kettes, de átmentél."))
        case .average: ("👌", String(localized: "Arany középút"), String(localized: "Nem rossz, nem kiváló: pont jó."))
        case .diligent: ("💫", String(localized: "Szorgalmas"), String(localized: "Sok órai munkád volt, ez meg is látszik."))
        case .npc: ("⛰️", String(localized: "Titokzatos"), String(localized: "Annyira kiegyensúlyozott vagy, hogy nem tudtunk besorolni."))
        }
    }
}

private enum StoryPage: Hashable {
    case start, grades, reportCard, lessons, numbers, personality

    static func pages(for s: YearSummary) -> [StoryPage] {
        var p: [StoryPage] = [.start, .grades]
        if !s.reportCard.isEmpty { p.append(.reportCard) }
        if s.best != nil { p.append(.lessons) }
        return p + [.numbers, .personality]
    }

    var title: LocalizedStringKey {
        switch self {
        case .start: "Összegezzünk hát..."
        case .grades: "Nézzük a jegyeidet... 📖"
        case .reportCard: "A bizonyítványod 🎓"
        case .lessons: "A kedvenc órád 💓"
        case .numbers: "Az éved számokban"
        case .personality: "A te személyiséged..."
        }
    }
}

/// A Firka összefoglalójának színátmenete, a Radír füzetlap-rácsával.
struct SummaryBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0x1D / 255, green: 0x56 / 255, blue: 0xAC / 255),
                                    Color(red: 0x17 / 255, green: 0x0A / 255, blue: 0x3D / 255)],
                           startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.9, y: 1))
            GridLines(spacing: 24)
                .stroke(.white.opacity(0.07), lineWidth: 1)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.2)], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A főoldal kártyája bizonyítványosztás után, az összefoglaló hátterével; időnként átfut rajta egy fénycsík.
struct SummaryBadge: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 22, weight: .bold))
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 3)), isActive: !reduceMotion)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Megjött a bizonyítványod!").font(.title(17, relativeTo: .headline))
                    Text("Jó éved volt? Nézzük meg!").font(.m(.subheadline)).opacity(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.m(.headline, .bold))
            }
            .foregroundStyle(.white)
            .padding(14)
            .background { SummaryBackground() }
            .overlay { if !reduceMotion { shine } }
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Megnyitja az év végi összefoglalót")
    }

    /// 4 másodpercenként egyszer átfut egy fénycsík.
    private var shine: some View {
        TimelineView(.animation) { ctx in
            let phase = min(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 1.2, 1)
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.25, height: geo.size.height * 2.5)
                    .rotationEffect(.degrees(20))
                    .offset(x: -geo.size.width * 0.35 + phase * geo.size.width * 1.7, y: -geo.size.height * 0.75)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Egy lap tartalma; a sorok egymás után csúsznak be jobbról, mint a Firkában.
private struct StoryPageView: View {
    let page: StoryPage
    let summary: YearSummary
    let book: GradeBook
    let revealed: Bool
    @Environment(\.palette) private var palette
    @State private var shown = false

    var body: some View {
        content.task { shown = true }
    }

    @ViewBuilder private var content: some View {
        let s = summary
        switch page {
        case .start:
            VStack(spacing: 6) {
                Image(systemName: "arrow.right").font(.system(size: 130, weight: .ultraLight))
                    .symbolEffect(.wiggle.right, options: .repeat(.periodic(delay: 2)), value: shown)
                Text("Kezdés").font(.m(.body, .medium)).opacity(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .slideIn(shown, 0)
        case .grades:
            let avgs = book.subjects.compactMap { sub in Averages.weighted(book.grades(for: sub)).map { (sub, $0) } }
            let top = avgs.filter { Averages.roundedGrade($0.1) >= 4 }
            let tryAgain = avgs.filter { (2...3).contains(Averages.roundedGrade($0.1)) }
            let oops = avgs.filter { Averages.roundedGrade($0.1) <= 1 }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if top.isEmpty {
                        Text("Nincsenek jegyek").font(.m(.title3, .semibold)).opacity(0.5)
                    }
                    ForEach(Array(top.enumerated()), id: \.offset) { i, row in subjectRow(row.0, Averages.roundedGrade(row.1)).slideIn(shown, Double(i) * 0.07) }
                    group("Próba teszi a mestert! 🔃", tryAgain, from: top.count)
                    group("Ajjaj... 🥴", oops, from: top.count + tryAgain.count)
                    if let avg = s.reportAverage ?? s.average {
                        VStack(spacing: 10) {
                            Text(s.reportAverage == nil ? "Az átlagod" : "Év végi átlagod").font(.custom("Montserrat-Bold", size: 21))
                            averagePill(avg)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .slideIn(shown, 0.3)
                    }
                }
            }
            .scrollIndicators(.hidden)
        case .reportCard:
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(s.reportCard.enumerated()), id: \.offset) { i, row in
                        subjectRow(row.subject, row.grade).slideIn(shown, Double(i) * 0.06)
                    }
                    if let avg = s.reportAverage {
                        averagePill(avg).frame(maxWidth: .infinity).padding(.top, 20).slideIn(shown, 0.4)
                    }
                }
            }
            .scrollIndicators(.hidden)
        case .lessons:
            VStack(alignment: .leading, spacing: 28) {
                if let b = s.best {
                    lessonBlock(b.subject, b.average, caption: nil).slideIn(shown, 0)
                }
                if let w = s.worst, w.subject.id != s.best?.subject.id {
                    lessonBlock(w.subject, w.average, caption: "Ez nem igazán tetszett...").slideIn(shown, 0.15)
                }
                if s.lateMinutes > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Késtél!").font(.custom("Montserrat-Bold", size: 21))
                        Text("Összesen \(s.lateMinutes) perc késés").font(.m(.title3)).opacity(0.8)
                    }
                    .slideIn(shown, 0.3)
                }
            }
        case .numbers:
            let first: [(String, LocalizedStringKey)] = [("\(s.gradeCount)", "jegy"), ("\(s.fives)", "ötös"), ("\(book.subjects.count)", "tantárgy")]
            let second: [(String, LocalizedStringKey)] = [("\(s.absenceCount)", "hiányzás"), ("\(s.unexcused)", "igazolatlan"), ("\(s.lateMinutes)", "perc késés")]
            VStack(spacing: 44) {
                numberRow(first).slideIn(shown, 0)
                numberRow(second).slideIn(shown, 0.12, fromLeading: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .personality:
            PersonalityCard(personality: s.personality, revealed: revealed)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .slideIn(shown, 0)
        }
    }

    @ViewBuilder
    private func group(_ title: LocalizedStringKey, _ rows: [(Subject, Double)], from offset: Int) -> some View {
        if !rows.isEmpty {
            Text(title).font(.custom("Montserrat-Bold", size: 21)).padding(.top, 16).slideIn(shown, Double(offset) * 0.07)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                subjectRow(row.0, Averages.roundedGrade(row.1)).slideIn(shown, Double(offset + i + 1) * 0.07)
            }
        }
    }

    private func subjectRow(_ subject: Subject, _ grade: Int) -> some View {
        HStack(spacing: 10) {
            gradeDot(grade)
            Text(subject.name).font(.system(size: 19, weight: .bold)).lineLimit(2)
        }
    }

    private func gradeDot(_ grade: Int) -> some View {
        Text("\(grade)")
            .font(.custom("Montserrat-ExtraBold", size: 15))
            .foregroundStyle(.black.opacity(0.75))
            .frame(width: 30, height: 30)
            .background(Color(palette.gradeColor(grade) ?? palette.accent), in: Circle())
    }

    private func averagePill(_ avg: Double) -> some View {
        let color = Color(palette.gradeColor(forAverage: avg))
        return CountUp(target: avg, decimals: 2, shown: shown)
            .font(.custom("Montserrat-ExtraBold", size: 32))
            .foregroundStyle(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
    }

    private func lessonBlock(_ subject: Subject, _ avg: Double, caption: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let caption { Text(caption).font(.custom("Montserrat-Bold", size: 21)) }
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: SubjectIcon.name(for: subject))
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(subject.name).font(.custom("Montserrat-ExtraBold", size: 26)).lineLimit(2).minimumScaleFactor(0.7)
                    averagePill(avg).scaleEffect(0.6, anchor: .leading).frame(height: 30, alignment: .leading)
                }
            }
        }
    }

    private func numberRow(_ items: [(String, LocalizedStringKey)]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.0).font(.custom("Montserrat-ExtraBold", size: 36)).monospacedDigit()
                    Text(item.1).font(.system(size: 17)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Felfelé pörgő szám.
private struct CountUp: View {
    let target: Double
    var decimals = 0
    let shown: Bool
    @State private var value = 0.0

    var body: some View {
        Text(value, format: .number.precision(.fractionLength(decimals)))
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .onChange(of: shown, initial: true) { _, isShown in
                guard isShown else { return }
                withAnimation(.smooth(duration: 1.1).delay(0.35)) { value = target }
            }
    }
}

/// Koppintásra megforduló kártya, felfedéskor konfettivel (mint a Firkában).
private struct PersonalityCard: View {
    let personality: YearSummary.Personality
    let revealed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let (emoji, title, text) = SummaryView.describe(personality)
        ZStack {
            card {
                Text(emoji).font(.system(size: 76))
                Text(title).font(.custom("Montserrat-ExtraBold", size: 28))
                Text(text).font(.m(.body, .medium)).multilineTextAlignment(.center).opacity(0.85)
            }
            .opacity(revealed ? 1 : 0)
            .rotation3DEffect(.degrees(revealed || reduceMotion ? 0 : -180), axis: (0, 1, 0))
            card {
                Image(systemName: "hand.tap.fill").font(.system(size: 44)).opacity(0.8)
                Text("Koppints a felfedéshez...").font(.m(.headline)).opacity(0.8)
            }
            .opacity(revealed ? 0 : 1)
            .rotation3DEffect(.degrees(revealed && !reduceMotion ? 180 : 0), axis: (0, 1, 0))
        }
        .accessibilityElement(children: .combine)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 12) { content() }
            .frame(maxWidth: .infinity, minHeight: 340)
            .padding(22)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

private struct Confetti: View {
    let start: Date

    private struct Piece {
        let vx, vy, spin, size: Double
        let color: Int
    }
    private static let pieces: [Piece] = (0..<80).map { _ in
        Piece(vx: .random(in: -1...1), vy: .random(in: -1.3 ... -0.4), spin: .random(in: -8...8),
              size: .random(in: 5...10), color: .random(in: 0..<5))
    }

    @Environment(\.palette) private var palette

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            Canvas { g, size in
                guard t < 3.5 else { return }
                for p in Self.pieces {
                    var c = g
                    c.opacity = max(0, min(1, 3.5 - t))
                    c.translateBy(x: size.width / 2 + p.vx * size.width * 0.6 * t,
                                  y: size.height * 0.4 + p.vy * 700 * t + 600 * t * t)
                    c.rotate(by: .radians(p.spin * t))
                    // a jegyszínekből
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                           with: .color(Color(palette.grades[p.color % palette.grades.count])))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private extension View {
    /// A Firka beúszása: jobbról (vagy balról) csúszik be, kis késleltetéssel.
    func slideIn(_ shown: Bool, _ delay: Double, fromLeading: Bool = false) -> some View {
        offset(x: shown ? 0 : (fromLeading ? -420 : 420))
            .opacity(shown ? 1 : 0)
            .animation(.smooth(duration: 0.55).delay(delay), value: shown)
    }
}
