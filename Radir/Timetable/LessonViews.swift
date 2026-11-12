import RadirKit
import SwiftUI

extension Date {
    /// Óra:perc budapesti idő szerint.
    var schoolTime: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Calendar.school.timeZone))
    }
}

/// Az óraszám körben; a folyamatban lévő óránál telített.
struct LessonIndexBadge: View {
    let text: String
    var isCurrent = false
    var isFree = false
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.custom("Montserrat-Bold", size: 15))
            .foregroundStyle(isCurrent ? .white : Color(isFree ? palette.secondaryText : palette.accent))
            .frame(width: 34, height: 34)
            .background(Circle().fill(isCurrent ? Color(palette.accent) : (isFree ? .clear : Color(palette.accentSoft))))
            .overlay(Circle().strokeBorder(Color(palette.separator), style: StrokeStyle(lineWidth: isFree ? 1.5 : 0, dash: [3, 3])))
            .accessibilityHidden(true)
    }
}

struct Tag: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

struct LessonRow: View {
    let lesson: Lesson
    var now: Date = .now
    @Environment(\.palette) private var palette

    private var isCurrent: Bool { lesson.start <= now && now < lesson.end && !lesson.isCancelled }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                LessonIndexBadge(text: lesson.index.map(String.init) ?? "+", isCurrent: isCurrent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title)
                        .font(.body.weight(.semibold))
                        .strikethrough(lesson.isCancelled)
                        .foregroundStyle(Color(lesson.isCancelled ? palette.secondaryText : palette.text))
                        .lineLimit(1)
                    subtitle
                    if lesson.isCancelled || lesson.isSubstitution || lesson.examID != nil {
                        HStack(spacing: 6) {
                            if lesson.isCancelled { Tag(text: "Elmarad", color: Color(palette.warning)) }
                            if lesson.isSubstitution { Tag(text: "Helyettesítés", color: Color(palette.accent)) }
                            if lesson.examID != nil { Tag(text: "Számonkérés", color: Color(palette.gradeColor(2)!)) }
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lesson.start.schoolTime).font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(lesson.end.schoolTime).font(.footnote.monospacedDigit()).foregroundStyle(Color(palette.secondaryText))
                }
                .foregroundStyle(Color(palette.text))
            }
            if isCurrent {
                ProgressView(timerInterval: lesson.start...lesson.end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(Color(palette.accent))
                    .padding(.leading, 46)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var subtitle: some View {
        let parts = [lesson.room, lesson.substituteTeacher ?? lesson.teacher].filter { !$0.isEmpty }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(Color(lesson.isSubstitution ? palette.accent : palette.secondaryText))
                .lineLimit(1)
        }
    }
}

struct FreeLessonRow: View {
    let index: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            LessonIndexBadge(text: String(index), isFree: true)
            Text("Lyukas óra").font(.body.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// Szünet két óra között, kártya nélkül. Ha éppen most van, kiemelve, visszaszámlálással.
struct BreakRow: View {
    let from: Date
    let to: Date
    var now: Date = .now
    @Environment(\.palette) private var palette

    var body: some View {
        let minutes = Int((to.timeIntervalSince(from) / 60).rounded())
        let isNow = from <= now && now < to
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption)
                .accessibilityHidden(true)
            if isNow {
                Text("Szünet, még")
                Text(timerInterval: now...to, countsDown: true).monospacedDigit()
            } else {
                Text("\(minutes) perc szünet")
            }
            Spacer()
            Text("\(from.schoolTime) – \(to.schoolTime)").monospacedDigit()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color(isNow ? palette.accent : palette.secondaryText))
        .padding(.horizontal, 14)
        .padding(.vertical, isNow ? 8 : 4)
        .background {
            if isNow { Capsule().fill(Color(palette.accentSoft)) }
        }
        .containerValue(\.panelPlain, true)
        .accessibilityElement(children: .combine)
    }
}

struct LessonDetailSheet: View {
    let lesson: Lesson
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: SubjectIcon.name(for: lesson.subject))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(palette.accent))
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color(palette.accentSoft)))
                        .accessibilityHidden(true)
                    Text(lesson.title).font(.title(26, relativeTo: .title)).multilineTextAlignment(.center)
                    Text("\(lesson.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())), \(lesson.start.schoolTime) – \(lesson.end.schoolTime)")
                        .font(.subheadline)
                        .foregroundStyle(Color(palette.secondaryText))
                    if lesson.isCancelled { Tag(text: "Elmarad", color: Color(palette.warning)) }
                }
                .padding(.top, 24)
                PanelGroup {
                    if !lesson.topic.isEmpty { detail("Téma", lesson.topic, "text.alignleft") }
                    if !lesson.room.isEmpty { detail("Terem", lesson.room, "door.left.hand.open") }
                    if !lesson.teacher.isEmpty { detail("Tanár", lesson.teacher, "person") }
                    if let sub = lesson.substituteTeacher { detail("Helyettes", sub, "person.badge.clock") }
                    if !lesson.groupName.isEmpty { detail("Csoport", lesson.groupName, "person.3") }
                    if let i = lesson.index { detail("Óraszám", "\(i).", "number") }
                    if let y = lesson.yearIndex { detail("Éves sorszám", "\(y).", "calendar") }
                    if lesson.wasAbsent { detail("Jelenlét", String(localized: "Hiányoztál"), "person.crop.circle.badge.xmark") }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detail(_ title: LocalizedStringKey, _ value: String, _ icon: String) -> some View {
        PanelRow(title: title, systemImage: icon) {
            Text(value).font(.subheadline).foregroundStyle(Color(palette.secondaryText)).multilineTextAlignment(.trailing)
        }
    }
}
