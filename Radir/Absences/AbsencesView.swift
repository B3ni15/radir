import RadirKit
import SwiftUI

struct AbsencesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @State private var detail: Absence?

    var body: some View {
        let items = app.school.absences ?? []
        let summary = AbsenceSummary(items)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if app.school.absences == nil && app.school.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if items.isEmpty {
                    PanelGroup {
                        PanelRow("Nincs hiányzásod", subtitle: "Így tovább!", systemImage: "hand.thumbsup.fill",
                                 tint: Color(palette.gradeColor(5)!))
                    }
                } else {
                    HStack(spacing: 8) {
                        stat("Igazolt", summary.excused, Color(palette.gradeColor(5)!))
                        stat("Igazolandó", summary.pending, Color(palette.gradeColor(2)!))
                        stat("Igazolatlan", summary.unexcused, Color(palette.warning))
                    }
                    if summary.lateCount > 0 {
                        PanelGroup {
                            PanelRow("\(summary.lateCount) késés", subtitle: "Összesen \(summary.lateMinutes) perc",
                                     systemImage: "clock.badge.exclamationmark", tint: Color(palette.gradeColor(2)!))
                        }
                    }
                    PanelGroup(title: "Tantárgyanként") {
                        ForEach(summary.bySubject) { group in
                            NavigationLink { SubjectAbsencesView(group: group) } label: { subjectRow(group) }
                                .buttonStyle(.plain)
                        }
                    }
                    PanelGroup(title: "Legutóbbi") {
                        ForEach(items.sorted { $0.date > $1.date }.prefix(5)) { a in
                            Button { detail = a } label: { AbsenceRow(absence: a) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .refreshable { await app.school.load(app) }
        .task(id: app.current?.id) { await app.school.load(app) }
        .sheet(item: $detail) { AbsenceDetailSheet(absence: $0) }
    }

    private func stat(_ title: LocalizedStringKey, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(.custom("Montserrat-Bold", size: 28, relativeTo: .title)).foregroundStyle(color)
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(palette.surface), in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func subjectRow(_ g: AbsenceSummary.BySubject) -> some View {
        HStack(spacing: 12) {
            Image(systemName: SubjectIcon.name(for: g.subject))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(palette.accent))
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(Color(palette.separator), lineWidth: 1.5))
                .accessibilityHidden(true)
            Text(g.subject.name).font(.body.weight(.semibold)).foregroundStyle(Color(palette.text)).lineLimit(2)
            Spacer(minLength: 8)
            if g.late > 0 { Tag(text: "\(g.late) késés", color: Color(palette.gradeColor(2)!)) }
            if g.absences > 0 { Tag(text: "\(g.absences) óra", color: Color(palette.warning)) }
            Chevron()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

struct SubjectAbsencesView: View {
    let group: AbsenceSummary.BySubject
    @State private var detail: Absence?

    var body: some View {
        ScrollView {
            PanelGroup {
                ForEach(group.items) { a in
                    Button { detail = a } label: { AbsenceRow(absence: a, showSubject: false) }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle(group.subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { AbsenceDetailSheet(absence: $0) }
    }
}
