import RadirKit
import SwiftUI

/// Kezdőlap: köszöntés, a mai nap élő kártyája, és a hírfolyam szűrő chipekkel.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var showSettings = false
    @State private var filter: Filter = .all
    @State private var gradeDetail: Grade?

    enum Filter: Hashable, CaseIterable {
        case all, grades, homework, exams, absences, notes, messages, wall, changes
        var title: LocalizedStringKey {
            switch self {
            case .all: "Összes"
            case .grades: "Jegyek"
            case .homework: "Feladatok"
            case .exams: "Számonkérések"
            case .absences: "Hiányzások"
            case .notes: "Beírások"
            case .messages: "Üzenetek"
            case .wall: "Faliújság"
            case .changes: "Változások"
            }
        }
    }

    @State private var homeworkDetail: Homework?
    @State private var examDetail: Exam?
    @State private var absenceDetail: Absence?
    @State private var noteDetail: SchoolNote?
    @State private var wallDetail: WallItem?
    @State private var messageDetail: KretaMessage?
    @State private var showMessages = false
    @State private var showSummary = false

    var body: some View {
        let now = Date.radirNow
        let all = sources(now: now)
        let available = [Filter.all] + Filter.allCases.dropFirst().filter { !entries(all, $0).isEmpty }
        let shown = filter == .all ? all : only(all, filter)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let news = app.server.unseenEmergency {
                    NewsCard(item: news) { withAnimation { app.server.markSeen(news) } }
                }
                if app.summaryBook != nil {
                    SummaryBadge { showSummary = true }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Ma", trailing: Text(now, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
                    TodayCard()
                }
                chips(available: available)

                ForEach(HomeFeed.days(shown)) { day in
                    PanelGroup(title: LocalizedStringKey(dayTitle(day.date))) {
                        ForEach(day.entries) { entry in
                            switch entry {
                            case .grade(let grade):
                                Button { gradeDetail = grade } label: { GradeRow(grade: grade, showSubject: true) }.buttonStyle(.plain)
                            case .change(let lesson):
                                Button { app.show(lesson) } label: { ChangeRow(lesson: lesson) }.buttonStyle(.plain)
                            case .homework(let h):
                                Button { homeworkDetail = h } label: {
                                    HomeworkRow(homework: h, isDone: app.notebook.notebook.doneHomework.contains(h.id))
                                }.buttonStyle(.plain)
                            case .exam(let e):
                                Button { examDetail = e } label: { ExamRow(exam: e) }.buttonStyle(.plain)
                            case .absence(let a):
                                Button { absenceDetail = a } label: { AbsenceRow(absence: a) }.buttonStyle(.plain)
                            case .note(let n):
                                Button { noteDetail = n } label: { SchoolNoteRow(note: n) }.buttonStyle(.plain)
                            case .message(let m):
                                Button { messageDetail = m } label: { MessageFeedRow(message: m) }.buttonStyle(.plain)
                            case .wall(let w):
                                Button { wallDetail = w } label: { WallRow(item: w) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                if available.count == 1 {
                    PanelGroup {
                        PanelRow("Nincs újdonság", subtitle: "Az új jegyeid és az órarendváltozások itt jelennek meg.",
                                 systemImage: "sparkles")
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .refreshable { await load() }
        .task(id: app.current?.id) { await load() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $gradeDetail) { GradeDetailSheet(grade: $0) }
        .sheet(item: $homeworkDetail) { HomeworkDetailSheet(homework: $0) }
        .sheet(item: $examDetail) { ExamDetailSheet(exam: $0) }
        .sheet(item: $absenceDetail) { AbsenceDetailSheet(absence: $0) }
        .sheet(item: $noteDetail) { SchoolNoteDetailSheet(note: $0) }
        .sheet(item: $wallDetail) { WallDetailSheet(item: $0) }
        .sheet(item: $messageDetail) { m in NavigationStack { MessageDetailView(message: m) } }
        .sheet(isPresented: $showMessages) { NavigationStack { MessagesView(showsClose: true) } }
        .fullScreenCover(isPresented: $showSummary) {
            if let book = app.summaryBook { SummaryView(book: book, absences: app.school.absences ?? []) }
        }
    }

    private func load() async {
        app.notebook.open(app)
        async let t: Void = app.timetable.loadAround(app, week: SchoolWeek(containing: .now))
        async let g: Void = app.grades.load(app)
        async let s: Void = app.school.load(app)
        async let m: Void = app.messages.load(app, .inbox)
        async let n: Void = app.server.refresh()
        _ = await (t, g, s, m, n)
    }

    /// Ami a hírfolyamba kerül: az utóbbi 30 nap, a házik és a számonkérések 14 napja, és a hátralévő változások.
    private func sources(now: Date) -> FeedSources {
        var f = FeedSources()
        f.grades = HomeFeed.recentGrades(app.grades.book?.grades ?? [], now: now)
        f.changes = HomeFeed.upcomingChanges(app.timetable.lessons[SchoolWeek(containing: now)] ?? [], now: now)
        f.homework = HomeFeed.recent(app.school.homework ?? [], now: now, days: 14) { $0.recorded ?? $0.assigned ?? .distantPast }
        f.exams = HomeFeed.recent(app.school.exams ?? [], now: now, days: 14) { $0.announced ?? .distantPast }
        f.absences = HomeFeed.recent(app.school.absences ?? [], now: now) { $0.lessonStart ?? $0.date }
        f.notes = HomeFeed.recent(app.school.notes ?? [], now: now) { $0.recorded ?? $0.date }
        f.messages = HomeFeed.recent(app.messages.boxes[.inbox] ?? [], now: now, days: 14) { $0.date }
        f.wall = (app.school.wall ?? []).filter { $0.isValid(at: now) }
        return f
    }

    private func entries(_ f: FeedSources, _ filter: Filter) -> [Any] {
        switch filter {
        case .all: []
        case .grades: f.grades
        case .homework: f.homework
        case .exams: f.exams
        case .absences: f.absences
        case .notes: f.notes
        case .messages: f.messages
        case .wall: f.wall
        case .changes: f.changes
        }
    }

    private func only(_ f: FeedSources, _ filter: Filter) -> FeedSources {
        var o = FeedSources()
        switch filter {
        case .all: return f
        case .grades: o.grades = f.grades
        case .homework: o.homework = f.homework
        case .exams: o.exams = f.exams
        case .absences: o.absences = f.absences
        case .notes: o.notes = f.notes
        case .messages: o.messages = f.messages
        case .wall: o.wall = f.wall
        case .changes: o.changes = f.changes
        }
        return o
    }

    /// „Ma”, „Holnap”, „Tegnap”, egyébként „Csütörtök, nov. 5.”
    private func dayTitle(_ date: Date) -> String {
        let cal = Calendar.school
        if cal.isDateInToday(date) { return String(localized: "Ma") }
        if cal.isDateInTomorrow(date) { return String(localized: "Holnap") }
        if cal.isDateInYesterday(date) { return String(localized: "Tegnap") }
        let s = date.formatted(Date.FormatStyle(timeZone: cal.timeZone).weekday(.wide).month(.abbreviated).day())
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func chips(available: [Filter]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(available, id: \.self) { f in
                    Button { withAnimation(.snappy) { filter = f } } label: { Chip(title: f.title, isSelected: filter == f) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        .onChange(of: available) { if !available.contains(filter) { filter = .all } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(greeting)
                .font(.title(28, relativeTo: .largeTitle))
                .foregroundStyle(Color(palette.text))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
            Button { showMessages = true } label: {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(palette.accent))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color(palette.surface)))
                    .overlay(alignment: .topTrailing) {
                        let unread = app.messages.unreadCount
                        if unread > 0 {
                            Text("\(unread)").font(.m(.caption2, .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                .background(Capsule().fill(Color(palette.warning)))
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Üzenetek")
            .accessibilityValue(app.messages.unreadCount > 0 ? Text("\(app.messages.unreadCount) olvasatlan") : Text(""))
            Button { showSettings = true } label: {
                AvatarView(name: app.current?.student.name ?? "", size: 46)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Beállítások")
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let first = app.current?.student.name.split(separator: " ").last.map(String.init) ?? ""
        let custom = app.prefs.welcomeMessage.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { return custom.replacingOccurrences(of: "%s", with: first) }
        let hour = Calendar.school.component(.hour, from: .radirNow)
        let format: String.LocalizationValue = switch hour {
        case 4..<10: "Jó reggelt, \(first)!"
        case 10..<18: "Szép napot, \(first)!"
        default: "Szép estét, \(first)!"
        }
        return String(localized: format)
    }
}

/// Helyettesítés vagy elmaradó óra a hírfolyamban.
private struct ChangeRow: View {
    let lesson: Lesson
    @Environment(\.palette) private var palette

    var body: some View {
        let tint = lesson.isCancelled ? Color(palette.warning) : .substitution
        HStack(spacing: 12) {
            Image(systemName: lesson.isCancelled ? "xmark" : "person.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.15)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.isCancelled ? "\(lesson.title) elmarad" : "\(lesson.title): helyettesítés")
                    .font(.m(.body, .semibold))
                    .foregroundStyle(Color(palette.text))
                    .lineLimit(1)
                Text(detail).font(.m(.footnote)).foregroundStyle(Color(palette.secondaryText)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private var detail: String {
        let base = "\(lesson.index.map { String(localized: "\($0). óra") + ", " } ?? "")\(lesson.start.schoolTime)"
        if let sub = lesson.substituteTeacher, !lesson.isCancelled { return "\(base) · \(sub)" }
        return base
    }
}
