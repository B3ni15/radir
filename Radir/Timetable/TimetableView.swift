import RadirKit
import SwiftUI

struct TimetableView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var selectedDay = Calendar.school.startOfDay(for: .now)
    @State private var detail: Lesson?
    @State private var direction: Edge = .trailing

    var body: some View {
        let model = app.timetable
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                weekHeader(model)
                dayStrip(model)
                dayContent(model)
                    .id(selectedDay)
                    .transition(.push(from: direction))
            }
            .padding(16)
        }
        .radirScreenBackground()
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 60 else { return }
            shiftDay(v.translation.width < 0 ? 1 : -1, model)
        })
        .refreshable { await model.load(app, week: model.week) }
        .task(id: TaskKey(account: app.current?.id, week: model.week)) {
            if !model.week.days.contains(selectedDay) { selectedDay = defaultDay(model.week) }
            await model.loadAround(app, week: model.week)
        }
        .sheet(item: $detail) { LessonDetailSheet(lesson: $0) }
        // a kezdőlapról érkező óra: a hetére és napjára ugrik, és megnyitja
        .onChange(of: app.openLesson, initial: true) { _, lesson in
            guard let lesson else { return }
            model.week = SchoolWeek(containing: lesson.date)
            selectedDay = lesson.date
            detail = lesson
            app.openLesson = nil
        }
    }

    private struct TaskKey: Hashable { let account: String?; let week: SchoolWeek }

    private func weekHeader(_ model: TimetableModel) -> some View {
        HStack(spacing: 10) {
            Button { move(-1, model) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                .accessibilityLabel("Előző hét")
            VStack(spacing: 2) {
                Text(rangeText(model.week)).font(.title(17, relativeTo: .headline))
                Text("\(model.week.number). hét").font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
            }
            .frame(maxWidth: .infinity)
            Button { move(1, model) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                .accessibilityLabel("Következő hét")
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(Color(palette.accent))
        .overlay(alignment: .trailing) {
            if model.week != SchoolWeek(containing: .now) {
                Button("Ma") {
                    direction = model.week.start > .now ? .leading : .trailing
                    withAnimation(.snappy) {
                        model.week = SchoolWeek(containing: .now)
                        selectedDay = Calendar.school.startOfDay(for: .now)
                    }
                }
                .font(.footnote.weight(.bold))
                .padding(.trailing, 44)
            }
        }
    }

    private func dayStrip(_ model: TimetableModel) -> some View {
        let today = Calendar.school.startOfDay(for: .now)
        let hasLessons = Set(model.days(for: model.week).map(\.date))
        return HStack(spacing: 6) {
            ForEach(model.week.days, id: \.self) { day in
                let selected = day == selectedDay
                Button {
                    direction = day > selectedDay ? .trailing : .leading
                    withAnimation(.snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 3) {
                        Text(day.formatted(Date.FormatStyle(timeZone: Calendar.school.timeZone).weekday(.abbreviated)).capitalized)
                            .font(.caption.weight(.semibold))
                        Text(day.formatted(Date.FormatStyle(timeZone: Calendar.school.timeZone).day()))
                            .font(.custom("Montserrat-Bold", size: 18, relativeTo: .headline))
                        Circle()
                            .fill(day == today ? (selected ? Color.white : Color(palette.accent)) : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selected ? Color.white : Color(hasLessons.contains(day) ? palette.text : palette.secondaryText))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Color(palette.accent) : Color(palette.surface)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func dayContent(_ model: TimetableModel) -> some View {
        if let day = model.days(for: model.week).first(where: { $0.date == selectedDay }) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                PanelGroup {
                    ForEach(day.items) { item in
                        switch item {
                        case .entry(.lesson(let lesson)):
                            Button { detail = lesson } label: { LessonRow(lesson: lesson, now: context.date) }
                                .buttonStyle(.plain)
                        case .entry(.free(let index, _)):
                            FreeLessonRow(index: index)
                        case .pause(let from, let to):
                            if isRelevantBreak(from: from, to: to, day: day, now: context.date) {
                                BreakRow(from: from, to: to, now: context.date)
                            }
                        }
                    }
                }
            }
        } else if model.loading.contains(model.week) && !model.hasLoaded(model.week) {
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        } else {
            PanelGroup {
                PanelRow(model.days(for: model.week).isEmpty ? "Ezen a héten nincs iskola" : "Ezen a napon nincs órád",
                         systemImage: "sun.max.fill", tint: Color(palette.gradeColor(3)!))
            }
        }
    }

    /// Csak a mostani óra előtti és utáni szünet, illetve az éppen tartó szünet látszik; más napokon egyik sem.
    private func isRelevantBreak(from: Date, to: Date, day: TimetableDay, now: Date) -> Bool {
        if from <= now && now < to { return true }
        guard let current = day.lessons.first(where: { !$0.isEvent && $0.start <= now && now < $0.end }) else { return false }
        return to == current.start || from == current.end
    }

    private func rangeText(_ week: SchoolWeek) -> String {
        let style = Date.FormatStyle(timeZone: Calendar.school.timeZone).month(.abbreviated).day()
        return "\(week.start.formatted(style)) – \(week.days.last!.formatted(style))"
    }

    private func defaultDay(_ week: SchoolWeek) -> Date {
        let today = Calendar.school.startOfDay(for: .now)
        return week.days.contains(today) ? today : week.days[0]
    }

    private func move(_ weeks: Int, _ model: TimetableModel) {
        direction = weeks > 0 ? .trailing : .leading
        // a hét napja marad: péntekről a következő hét péntekére
        let offset = model.week.days.firstIndex(of: selectedDay) ?? 0
        withAnimation(.snappy) {
            model.week = weeks > 0 ? model.week.next : model.week.previous
            selectedDay = model.week.days[offset]
        }
    }

    private func shiftDay(_ delta: Int, _ model: TimetableModel) {
        guard let i = model.week.days.firstIndex(of: selectedDay) else { return }
        let j = i + delta
        if j < 0 {
            direction = .leading
            withAnimation(.snappy) { model.week = model.week.previous; selectedDay = model.week.days[4] }
        } else if j > 4 {
            direction = .trailing
            withAnimation(.snappy) { model.week = model.week.next; selectedDay = model.week.days[0] }
        } else {
            direction = delta > 0 ? .trailing : .leading
            withAnimation(.snappy) { selectedDay = model.week.days[j] }
        }
    }
}
