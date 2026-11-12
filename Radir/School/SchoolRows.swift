import RadirKit
import SwiftUI

/// „ma”, „holnap”, „tegnap”, egyébként „csütörtök, nov. 5.”
func relativeDay(_ date: Date, capitalized: Bool = false) -> String {
    let cal = Calendar.school
    let s = cal.isDateInToday(date) ? String(localized: "ma")
        : cal.isDateInTomorrow(date) ? String(localized: "holnap")
        : cal.isDateInYesterday(date) ? String(localized: "tegnap")
        : cal.component(.year, from: date) == cal.component(.year, from: .now)
            ? date.formatted(Date.FormatStyle(timeZone: cal.timeZone).weekday(.wide).month(.abbreviated).day())
            : date.formatted(Date.FormatStyle(timeZone: cal.timeZone).year().month(.abbreviated).day())
    return capitalized ? s.prefix(1).uppercased() + s.dropFirst() : s
}

/// Kör alakú ikon a sor elején, a kategória színével.
struct CategoryIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(Circle().fill(color.opacity(0.15)))
            .accessibilityHidden(true)
    }
}

/// Egy hírfolyam- vagy listasor egységes felépítése.
struct InfoRow: View {
    let icon: CategoryIcon
    let title: String
    let subtitle: String
    var trailing: AnyView?
    var dimmed = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Color(palette.text)).lineLimit(1)
                    .strikethrough(dimmed)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.footnote).foregroundStyle(Color(palette.secondaryText)).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .opacity(dimmed ? 0.55 : 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

extension Absence {
    var stateText: LocalizedStringKey {
        switch state {
        case .excused: "Igazolt"
        case .unexcused: "Igazolatlan"
        case .pending: "Igazolandó"
        }
    }

    func stateColor(_ p: Palette) -> Color {
        switch state {
        case .excused: Color(p.gradeColor(5)!)
        case .unexcused: Color(p.warning)
        case .pending: Color(p.gradeColor(2)!)
        }
    }
}

struct AbsenceRow: View {
    let absence: Absence
    var showSubject = true
    @Environment(\.palette) private var palette

    var body: some View {
        let lesson = [absence.lessonIndex.map { "\($0). óra" }, absence.lessonStart?.schoolTime].compactMap { $0 }.joined(separator: ", ")
        InfoRow(icon: CategoryIcon(systemImage: absence.kind == .late ? "clock.badge.exclamationmark" : "person.crop.circle.badge.xmark",
                                   color: absence.stateColor(palette)),
                title: absence.kind == .late ? String(localized: "\(absence.subject.name): késés \(absence.delayMinutes) perc")
                    : (showSubject ? absence.subject.name : relativeDay(absence.date, capitalized: true)),
                subtitle: showSubject ? "\(relativeDay(absence.date, capitalized: true)) · \(lesson)" : lesson,
                trailing: AnyView(Tag(text: absence.stateText, color: absence.stateColor(palette))))
    }
}

struct HomeworkRow: View {
    let homework: Homework
    var isDone = false
    @Environment(\.palette) private var palette

    var body: some View {
        InfoRow(icon: CategoryIcon(systemImage: isDone ? "checkmark" : "house.fill", color: Color(palette.accent)),
                title: homework.subject.name,
                subtitle: "\(deadlineText(homework.deadline)) · \(homework.plainText.replacingOccurrences(of: "\n", with: " "))",
                dimmed: isDone)
    }
}

/// „Mára”, „Holnapra”, egyébként „Határidő: péntek, nov. 13.”
func deadlineText(_ date: Date) -> String {
    let cal = Calendar.school
    if cal.isDateInToday(date) { return String(localized: "Mára") }
    if cal.isDateInTomorrow(date) { return String(localized: "Holnapra") }
    return String(localized: "Határidő: \(relativeDay(date))")
}

struct ExamRow: View {
    let exam: Exam
    @Environment(\.palette) private var palette

    var body: some View {
        InfoRow(icon: CategoryIcon(systemImage: "pencil.and.list.clipboard", color: Color(palette.gradeColor(2)!)),
                title: exam.topic.isEmpty ? exam.subject.name : "\(exam.subject.name): \(exam.topic)",
                subtitle: [relativeDay(exam.date, capitalized: true), exam.lessonIndex.map { "\($0). óra" }, exam.mode.isEmpty ? nil : exam.mode]
                    .compactMap { $0 }.joined(separator: " · "))
    }
}

struct SchoolNoteRow: View {
    let note: SchoolNote
    @Environment(\.palette) private var palette

    var body: some View {
        InfoRow(icon: CategoryIcon(systemImage: "text.bubble.fill", color: Color(palette.accent)),
                title: note.title, subtitle: "\(note.teacher) · \(note.content.replacingOccurrences(of: "\n", with: " "))")
    }
}

/// Közös részlet sheet: ikon, cím, alcím, sorok, opcionális szöveg.
struct DetailSheet<Extra: View>: View {
    let icon: CategoryIcon
    let title: String
    let subtitle: String
    let rows: [(LocalizedStringKey, String, String)]
    var text: String?
    @ViewBuilder var extra: Extra
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    icon.scaleEffect(1.6).frame(height: 70)
                    Text(title).font(.title(24, relativeTo: .title)).multilineTextAlignment(.center)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(Color(palette.secondaryText)).multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)
                if let text, !text.isEmpty {
                    Text(text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).radirPanel()
                }
                PanelGroup {
                    ForEach(rows.indices, id: \.self) { i in
                        PanelRow(title: rows[i].0, systemImage: rows[i].2) {
                            Text(rows[i].1).font(.subheadline).foregroundStyle(Color(palette.secondaryText)).multilineTextAlignment(.trailing)
                        }
                    }
                }
                extra
            }
            .padding(16)
        }
        .radirScreenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

extension DetailSheet where Extra == EmptyView {
    init(icon: CategoryIcon, title: String, subtitle: String, rows: [(LocalizedStringKey, String, String)], text: String? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle, rows: rows, text: text) { EmptyView() }
    }
}

struct AbsenceDetailSheet: View {
    let absence: Absence
    @Environment(\.palette) private var palette

    var body: some View {
        var rows: [(LocalizedStringKey, String, String)] = [("Állapot", String(localized: absence.state == .excused ? "Igazolt" : absence.state == .pending ? "Igazolandó" : "Igazolatlan"), "checkmark.seal")]
        if !absence.justification.isEmpty { rows.append(("Igazolás", absence.justification, "doc.text")) }
        if let i = absence.lessonIndex { rows.append(("Óra", "\(i).", "number")) }
        if let s = absence.lessonStart, let e = absence.lessonEnd { rows.append(("Időpont", "\(s.schoolTime) – \(e.schoolTime)", "clock")) }
        if absence.kind == .late { rows.append(("Késés", String(localized: "\(absence.delayMinutes) perc"), "timer")) }
        if !absence.teacher.isEmpty { rows.append(("Rögzítette", absence.teacher, "person")) }
        return DetailSheet(icon: CategoryIcon(systemImage: absence.kind == .late ? "clock.badge.exclamationmark" : "person.crop.circle.badge.xmark",
                                              color: absence.stateColor(palette)),
                           title: absence.kind == .late ? String(localized: "Késés") : String(localized: "Hiányzás"),
                           subtitle: "\(absence.subject.name) · \(relativeDay(absence.date, capitalized: true))", rows: rows)
    }
}

struct HomeworkDetailSheet: View {
    let homework: Homework
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        let done = app.notebook.notebook.doneHomework.contains(homework.id)
        var rows: [(LocalizedStringKey, String, String)] = [("Határidő", relativeDay(homework.deadline, capitalized: true), "calendar")]
        if !homework.teacher.isEmpty { rows.append(("Tanár", homework.teacher, "person")) }
        for a in homework.attachments { rows.append(("Csatolmány", a.name, "paperclip")) }
        return DetailSheet(icon: CategoryIcon(systemImage: "house.fill", color: Color(palette.accent)),
                           title: homework.subject.name, subtitle: String(localized: "Házi feladat"), rows: rows,
                           text: homework.plainText) {
            Button {
                app.notebook.update { nb in
                    if done { nb.doneHomework.remove(homework.id) } else { nb.doneHomework.insert(homework.id) }
                }
            } label: {
                Label(done ? "Mégsincs kész" : "Kész vagyok vele", systemImage: done ? "arrow.uturn.backward" : "checkmark")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
            }
            .radirProminentButton()
            .controlSize(.large)
        }
    }
}

struct ExamDetailSheet: View {
    let exam: Exam
    @Environment(\.palette) private var palette

    var body: some View {
        var rows: [(LocalizedStringKey, String, String)] = [("Időpont", relativeDay(exam.date, capitalized: true), "calendar")]
        if let i = exam.lessonIndex { rows.append(("Óra", "\(i).", "number")) }
        if !exam.mode.isEmpty { rows.append(("Mód", exam.mode, "pencil.and.list.clipboard")) }
        if !exam.teacher.isEmpty { rows.append(("Tanár", exam.teacher, "person")) }
        if let a = exam.announced { rows.append(("Bejelentve", a.formatted(date: .abbreviated, time: .omitted), "megaphone")) }
        return DetailSheet(icon: CategoryIcon(systemImage: "pencil.and.list.clipboard", color: Color(palette.gradeColor(2)!)),
                           title: exam.topic.isEmpty ? exam.subject.name : exam.topic, subtitle: exam.subject.name, rows: rows)
    }
}

struct SchoolNoteDetailSheet: View {
    let note: SchoolNote
    @Environment(\.palette) private var palette

    var body: some View {
        DetailSheet(icon: CategoryIcon(systemImage: "text.bubble.fill", color: Color(palette.accent)),
                    title: note.title, subtitle: note.kind,
                    rows: [("Tanár", note.teacher, "person"), ("Dátum", relativeDay(note.date, capitalized: true), "calendar")],
                    text: note.content)
    }
}

struct WallRow: View {
    let item: WallItem
    @Environment(\.palette) private var palette

    var body: some View {
        InfoRow(icon: CategoryIcon(systemImage: "pin.fill", color: Color(palette.warning)),
                title: item.title, subtitle: item.plainText.replacingOccurrences(of: "\n", with: " "))
    }
}

struct WallDetailSheet: View {
    let item: WallItem
    @Environment(\.palette) private var palette

    var body: some View {
        DetailSheet(icon: CategoryIcon(systemImage: "pin.fill", color: Color(palette.warning)),
                    title: item.title, subtitle: String(localized: "Faliújság"),
                    rows: [("Érvényes", "\(item.start.formatted(date: .abbreviated, time: .omitted)) – \(item.end.formatted(date: .abbreviated, time: .omitted))", "calendar")],
                    text: item.plainText)
    }
}

struct MessageFeedRow: View {
    let message: KretaMessage
    @Environment(\.palette) private var palette

    var body: some View {
        InfoRow(icon: CategoryIcon(systemImage: message.isRead ? "envelope.open.fill" : "envelope.badge.fill", color: Color(palette.accent)),
                title: message.subject, subtitle: message.sender)
    }
}
