import RadirKit
import SwiftUI

/// A Firka „live card”-ja: ami most van, egyetlen kártyán, alatta a következő óra.
/// Bármelyik órára koppintva az Órarend fül nyílik, az óra részleteivel.
struct TodayCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = Date.radirNow.addingTimeInterval(TimeInterval(app.prefs.bellDelay))
            let lessons = LiveCard.relevant(app.timetable.day(now)?.lessons ?? [])
            let current = lessons.first { $0.start <= now && now < $0.end }
            let next = lessons.first { $0.start > now }
            let prev = lessons.last { $0.end <= now }

            PanelGroup {
                if let current {
                    nowCard(icon: SubjectIcon.name(for: current.subject), title: current.title,
                            subtitle: [current.room, current.substituteTeacher ?? current.teacher].filter { !$0.isEmpty }.joined(separator: " · "),
                            highlight: current.isSubstitution, from: current.start, to: current.end, now: now)
                        .onTapGesture { app.show(current) }
                } else if let next, prev != nil {
                    nowCard(icon: "cup.and.saucer.fill", title: String(localized: "Szünet"),
                            subtitle: String(localized: "Következő: \(next.title), \(next.room)"),
                            highlight: false, from: prev!.end, to: next.start, now: now)
                        .onTapGesture { app.show(next) }
                } else if let next {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hamarosan kezdődik az első órád!").font(.title(18, relativeTo: .headline))
                        CountdownDigits(remaining: next.start.timeIntervalSince(now))
                    }
                    .padding(16)
                    .contentShape(.rect)
                    .onTapGesture { app.show(next) }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lessons.isEmpty ? "Ma nincs órád" : "Mára végeztél!").font(.title(18, relativeTo: .headline))
                        Text(lessons.isEmpty ? "Pihenj, vagy nézd meg a heti órarendet." : "Ma nincs több órád.")
                            .font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText))
                    }
                    .padding(16)
                    .contentShape(.rect)
                    .onTapGesture { app.tab = .timetable }
                }

                if let next {
                    Button { app.show(next) } label: { nextRow(next, now: now) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func nowCard(icon: String, title: String, subtitle: String, highlight: Bool,
                         from: Date, to: Date, now: Date) -> some View {
        // a rendszeróra szerinti időzítők; DEBUG-ban a `-RadirClock` eltolásával
        let shift = Date.radirNow.timeIntervalSinceNow
        let (from, to, now) = (from - shift, to - shift, now - shift)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(palette.accent)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title(20, relativeTo: .headline)).lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.m(.footnote))
                            .foregroundStyle(Color(highlight ? palette.accent : palette.secondaryText))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("még").font(.m(.caption, .semibold)).foregroundStyle(Color(palette.secondaryText))
                    Text(timerInterval: now...max(now, to), countsDown: true)
                        .font(.custom("Montserrat-Bold", size: 22, relativeTo: .title2))
                        .monospacedDigit()
                        .foregroundStyle(Color(palette.accent))
                }
            }
            ProgressView(timerInterval: from...max(from, to), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(Color(palette.accent))
        }
        .padding(16)
        .contentShape(.rect)
    }

    private func nextRow(_ lesson: Lesson, now: Date) -> some View {
        HStack(spacing: 12) {
            LessonIndexBadge(text: lesson.index.map(String.init) ?? "+")
            VStack(alignment: .leading, spacing: 2) {
                Text("Következő").font(.m(.caption, .semibold)).foregroundStyle(Color(palette.secondaryText))
                Text(lesson.title).font(.m(.body, .semibold)).foregroundStyle(Color(palette.text)).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(lesson.start.schoolTime).font(.m(.subheadline, .semibold).monospacedDigit())
                if !lesson.room.isEmpty {
                    Text(lesson.room).font(.m(.footnote)).foregroundStyle(Color(palette.secondaryText))
                }
            }
            .foregroundStyle(Color(palette.text))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

/// A Firka visszaszámlálója: számjegyek külön dobozban, mellettük az egység.
struct CountdownDigits: View {
    let remaining: TimeInterval
    @Environment(\.palette) private var palette

    var body: some View {
        let total = max(0, Int(remaining))
        let parts: [(Int, LocalizedStringKey)] = [(total / 3600, "óra"), (total % 3600 / 60, "perc"), (total % 60, "mp")]
        HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if i > 0 || part.0 > 0 {
                    HStack(spacing: 3) {
                        ForEach(Array(String(format: i == 0 ? "%d" : "%02d", part.0).enumerated()), id: \.offset) { _, ch in
                            Text(String(ch))
                                .font(.custom("Montserrat-Bold", size: 20, relativeTo: .title3))
                                .frame(width: 26, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(palette.background)))
                        }
                        Text(part.1).font(.m(.subheadline, .medium)).foregroundStyle(Color(palette.secondaryText))
                            .padding(.leading, 2)
                    }
                }
            }
        }
        .contentTransition(.numericText(countsDown: true))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Duration.seconds(total).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))))
    }
}
