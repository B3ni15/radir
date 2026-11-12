import RadirKit
import SwiftUI

/// A jegy kör alakú jelvénye: a jegy színével halványan kitöltve, szöveges értékelésnél a rövid név.
struct GradeBubble: View {
    let grade: Grade
    var size: CGFloat = 40
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let color = Color(palette.gradeColor(grade.value) ?? palette.secondaryText)
        Text(grade.value > 0 ? String(grade.value) : String(grade.shortName.prefix(2)))
            .font(.custom("Montserrat-Bold", size: size * 0.48))
            .foregroundStyle(color.gradeInk(scheme))
            .frame(width: size, height: size)
            .background(Circle().fill(color.opacity(0.22)))
            .overlay(Circle().strokeBorder(color.opacity(0.5), lineWidth: grade.weight > 100 ? 2 : 0))
            .accessibilityLabel(Text(grade.valueName.isEmpty ? String(grade.value) : grade.valueName))
    }
}

struct GradeRow: View {
    let grade: Grade
    var showSubject = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            GradeBubble(grade: grade)
            VStack(alignment: .leading, spacing: 2) {
                Text(showSubject ? grade.subject.name : (grade.topic.isEmpty ? grade.mode : grade.topic))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(palette.text))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color(palette.secondaryText))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if grade.weight != 100 && grade.weight > 0 {
                Text("\(grade.weight)%")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(Color(palette.accent))
                    .background(Capsule().fill(Color(palette.accentSoft)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private var subtitle: String {
        let date = grade.date.formatted(.dateTime.month(.abbreviated).day())
        let detail = showSubject ? (grade.topic.isEmpty ? grade.mode : grade.topic) : (grade.topic.isEmpty ? "" : grade.mode)
        return detail.isEmpty ? date : "\(detail) · \(date)"
    }
}

/// Jegyeloszlás színes csíkként, kinyitva darabszámokkal.
struct GradeDistribution: View {
    let grades: [Grade]
    @State private var expanded = false
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let d = Averages.distribution(grades)
        let total = d.values.reduce(0, +)
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                HStack(spacing: 12) {
                    Text("Jegyek száma: \(total)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(palette.text))
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { v in
                                if let n = d[v], n > 0 {
                                    Capsule()
                                        .fill(Color(palette.gradeColor(v)!))
                                        .frame(width: max(6, (geo.size.width - 12) * CGFloat(n) / CGFloat(max(total, 1))))
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 10)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(palette.secondaryText))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Megmutatja, melyik jegyből hány van")

            if expanded {
                HStack(spacing: 8) {
                    ForEach((1...5).reversed(), id: \.self) { v in
                        HStack(spacing: 4) {
                            Text(String(v))
                                .font(.custom("Montserrat-Bold", size: 15))
                                .foregroundStyle(Color(palette.gradeColor(v)!).gradeInk(scheme))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color(palette.gradeColor(v)!).opacity(0.22)))
                            Text("×\(d[v] ?? 0)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color(palette.text))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
    }
}

/// Felfelé vagy lefelé mutató nyíl a változással.
struct TrendLabel: View {
    let delta: Double
    @Environment(\.palette) private var palette

    var body: some View {
        if abs(delta) >= 0.01 {
            let up = delta > 0
            Label {
                Text(abs(delta), format: .number.precision(.fractionLength(2)))
            } icon: {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
            }
            .font(.caption.weight(.bold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color(up ? palette.gradeColor(5)! : palette.warning))
            .accessibilityLabel(up ? "Javult" : "Romlott")
        }
    }
}
