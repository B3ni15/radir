import RadirKit
import SwiftUI

struct GradesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var period = 0

    private static let periods: [(days: Int, title: LocalizedStringKey)] = [
        (0, "Év"), (90, "3 hónap"), (30, "30 nap"), (14, "14 nap"), (7, "7 nap"),
    ]

    var body: some View {
        let model = app.grades
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let book = model.book {
                    content(book)
                } else if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .refreshable { await model.load(app) }
        .task(id: app.current?.id) { await model.load(app) }
        .navigationDestination(for: Subject.self) { subject in
            if let book = model.book { SubjectView(subject: subject, book: book) }
        }
    }

    @ViewBuilder
    private func content(_ book: GradeBook) -> some View {
        let all = book.midYear
        let days = Self.periods[period].days
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86_400)
        let shown = days == 0 ? all : all.filter { $0.date >= cutoff }

        header(book, all: all, days: days)

        if all.isEmpty {
            PanelGroup {
                PanelRow("Még nincs jegyed", subtitle: "Ha beírják az első jegyedet, itt látod.", systemImage: "sparkles")
            }
        } else {
            PanelGroup {
                AverageChart(points: Averages.timeline(shown, gapDays: 2), classAverage: book.overallClassAverage)
                GradeDistribution(grades: shown)
            }
            PanelGroup(title: "Tantárgyaid") {
                ForEach(book.subjects) { subject in
                    NavigationLink(value: subject) { subjectRow(subject, book: book, days: days) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func header(_ book: GradeBook, all: [Grade], days: Int) -> some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Időszak", selection: $period) {
                    ForEach(Self.periods.indices, id: \.self) { i in Text(Self.periods[i].title).tag(i) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(Self.periods[period].title)
                    Image(systemName: "chevron.down").font(.m(.caption, .bold))
                }
                .font(.m(.subheadline, .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(Color(palette.text))
                .background(Capsule().fill(Color(palette.surface)))
            }
            Spacer()
            if let trend = Averages.trend(all, days: days) { TrendLabel(delta: trend) }
            if let avg = Averages.weighted(all) { AverageBadge(value: avg) }
            if let cls = book.overallClassAverage {
                AverageBadge(value: cls, filled: true)
                    .accessibilityLabel(Text("Osztályátlag: \(cls, format: .number.precision(.fractionLength(2)))"))
            }
        }
    }

    private func subjectRow(_ subject: Subject, book: GradeBook, days: Int) -> some View {
        let grades = book.grades(for: subject)
        return HStack(spacing: 12) {
            Image(systemName: SubjectIcon.name(for: subject))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(palette.text).opacity(0.75))
                .frame(width: 32, height: 38)
                .accessibilityHidden(true)
            Text(subject.name)
                .font(.m(.body, .semibold))
                .foregroundStyle(Color(palette.text))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            if let trend = Averages.trend(grades, days: days) { TrendLabel(delta: trend) }
            if let avg = Averages.weighted(grades) {
                AverageBadge(value: avg)
            } else {
                Text("–").foregroundStyle(Color(palette.secondaryText))
            }
            if let cls = book.classAverage(for: subject) { AverageBadge(value: cls, filled: true) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}
