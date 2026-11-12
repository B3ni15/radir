import RadirKit
import SwiftUI

/// A teljes hét egy táblázatban (a legacy teljes képernyős órarendje): oszlopok a napok, sorok az óraszámok.
struct WeekGridView: View {
    let week: SchoolWeek
    let days: [TimetableDay]
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var detail: Lesson?

    var body: some View {
        let indices = Array(Set(days.flatMap(\.lessons).compactMap(\.index))).sorted()
        NavigationStack {
            GeometryReader { geo in
            // az öt nap kiférjen egy képernyőre
            let w = max(48, (geo.size.width - 24 - 22 - 5 * 4) / 5)
            ScrollView(.vertical) {
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        Color.clear.frame(width: 22, height: 1)
                        ForEach(week.days, id: \.self) { d in
                            Text(d.formatted(Date.FormatStyle(timeZone: Calendar.school.timeZone).weekday(.abbreviated)).capitalized)
                                .font(.caption.weight(.bold)).foregroundStyle(Color(palette.secondaryText))
                                .frame(width: w)
                        }
                    }
                    ForEach(indices, id: \.self) { i in
                        GridRow {
                            Text("\(i)").font(.custom("Montserrat-Bold", size: 14)).foregroundStyle(Color(palette.accent)).frame(width: 22)
                            ForEach(week.days, id: \.self) { d in
                                cell(days.first { $0.date == d }?.lessons.first { $0.index == i }, width: w)
                            }
                        }
                    }
                }
                .padding(12)
            }
            }
            .radirScreenBackground()
            .navigationTitle("\(week.number). hét")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kész") { dismiss() } } }
            .sheet(item: $detail) { LessonDetailSheet(lesson: $0) }
        }
    }

    @ViewBuilder
    private func cell(_ lesson: Lesson?, width: CGFloat) -> some View {
        if let l = lesson {
            Button { detail = l } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.title).font(.caption2.weight(.semibold)).lineLimit(3).minimumScaleFactor(0.8).strikethrough(l.isCancelled)
                    Text(l.room).font(.system(size: 10)).foregroundStyle(Color(palette.secondaryText)).lineLimit(1)
                }
                .frame(width: width - 10, height: 56, alignment: .topLeading)
                .padding(5)
                .foregroundStyle(Color(palette.text))
                .background(Color(l.isChanged ? palette.accentSoft : palette.surface), in: .rect(cornerRadius: 10, style: .continuous))
                .opacity(l.isCancelled ? 0.5 : 1)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: width, height: 66)
        }
    }
}
