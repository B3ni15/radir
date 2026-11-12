import Charts
import RadirKit
import SwiftUI

/// Halmozott átlag időben; a vonal színe a jegyszínek szerint változik, alul halvány kitöltés.
struct AverageChart: View {
    let points: [AveragePoint]
    var classAverage: Double?
    @Environment(\.palette) private var palette

    /// A vonal saját magasságára feszül, ezért a színeket a vonal legkisebb és legnagyobb átlagából számoljuk.
    private var lineGradient: LinearGradient {
        let lo = points.map(\.average).min() ?? 1, hi = points.map(\.average).max() ?? 5
        let stops = (0...5).map { i -> Gradient.Stop in
            let t = Double(i) / 5
            return .init(color: Color(palette.gradeColor(forAverage: lo + (hi - lo) * t)), location: t)
        }
        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    var body: some View {
        Group {
            if points.isEmpty {
                Text("Még nincs elég jegy a grafikonhoz.")
                    .font(.subheadline)
                    .foregroundStyle(Color(palette.secondaryText))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    if let classAverage {
                        RuleMark(y: .value("Osztályátlag", classAverage))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color(palette.secondaryText).opacity(0.6))
                    }
                    ForEach(points, id: \.self) { p in
                        AreaMark(x: .value("Dátum", p.date), yStart: .value("", 1), yEnd: .value("Átlag", p.average))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [Color(palette.accent).opacity(0.18), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Dátum", p.date), y: .value("Átlag", p.average))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(lineGradient)
                    }
                    if points.count == 1, let p = points.first {
                        PointMark(x: .value("Dátum", p.date), y: .value("Átlag", p.average))
                            .foregroundStyle(Color(palette.gradeColor(forAverage: p.average)))
                    }
                }
                .chartYScale(domain: 1...5)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Color(palette.separator))
                        AxisValueLabel().font(.footnote.weight(.semibold)).foregroundStyle(Color(palette.secondaryText))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color(palette.secondaryText))
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Átlag grafikon")
                .accessibilityValue(points.last.map { Text($0.average, format: .number.precision(.fractionLength(2))) } ?? Text(""))
            }
        }
        .padding(16)
    }
}
