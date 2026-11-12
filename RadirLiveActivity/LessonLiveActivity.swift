import ActivityKit
import RadirKit
import SwiftUI
import WidgetKit

/// Az óra élő kártyája a zárolt képernyőn és a Dynamic Islandben, a legacy (reFilc) elrendezését követve.
/// A tartalmat a szerver pusholja (vagy az app frissíti előtérben), a formátum a `LiveCardContent`.
struct LessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadirLiveAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(context.state.tint)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressRing(state: s, size: 44)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    TextBlock(state: s, compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: s)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(s.tint)
                        .frame(minWidth: 64, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: s.icon).foregroundStyle(s.tint)
            } compactTrailing: {
                Countdown(state: s)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(s.tint)
                    .frame(width: 52)
            } minimal: {
                ProgressRing(state: s, size: 22)
            }
            .keylineTint(s.tint)
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

/// Zárolt képernyő: ikon a haladás körében, középen a szöveg, jobbra a visszaszámláló.
private struct LockScreenView: View {
    let state: LiveCardContent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ProgressRing(state: state, size: 46)
            TextBlock(state: state, compact: false)
                .layoutPriority(0)
            Spacer(minLength: 4)
            Countdown(state: state)
                .font(state.longCountdown ? .title3.weight(.bold) : .title2.weight(.bold))
                .foregroundStyle(state.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                // a visszaszámláló magától teljes szélességet kérne, ezért korlátos keret kell (mint a legacyban)
                .frame(minWidth: 86, maxWidth: 100, alignment: .trailing)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// A legacy szövegei: cím, leírás, következő óra (vagy „utolsó óra”).
private struct TextBlock: View {
    let state: LiveCardContent
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            Text(state.headline)
                .font(compact ? .subheadline.weight(.bold) : .system(size: 16, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let detail = state.detail {
                Text(detail)
                    .font(compact ? .caption : .system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let next = state.nextLine {
                if compact {
                    Text("Következő óra és terem:").font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
                    Text(next).font(.caption).lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
                        Text(next).font(.system(size: 12)).lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            } else if state.isLesson {
                Text("Ez az utolsó óra! Kitartást!")
                    .font(compact ? .caption : .system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Kör alakú haladásjelző, benne a tantárgy (vagy szünet) ikonja.
private struct ProgressRing: View {
    let state: LiveCardContent
    let size: CGFloat

    var body: some View {
        ZStack {
            if state.isRunning {
                ProgressView(timerInterval: state.date, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
                    .tint(state.tint)
            } else {
                Circle().stroke(state.tint.opacity(0.35), lineWidth: 3)
            }
            Image(systemName: state.icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(state.tint)
        }
        .frame(width: size, height: size)
    }
}

private struct Countdown: View {
    let state: LiveCardContent

    var body: some View {
        if state.isRunning {
            Text(timerInterval: state.date, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("Vége")
        }
    }
}

extension LiveCardContent {
    var tint: Color {
        let c = ARGB(hex: color) ?? ARGB(0xFF2F_6FEB)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    /// Még tart (az időtartam nem nulla, és nem járt le).
    var isRunning: Bool { date.upperBound > date.lowerBound && date.upperBound > .now }

    /// Óra (nem szünet, nem reggeli visszaszámlálás, nem „vége”).
    var isLesson: Bool { !index.isEmpty }

    var longCountdown: Bool { date.upperBound.timeIntervalSinceNow >= 3600 }

    /// „5. Matematika”, „Szünet”, „Az első órádig:”
    var headline: String { isLesson ? "\(index)\(title)" : title }

    /// „Terem: 201 · Geometria” vagy a szünet leírása.
    var detail: String? {
        let parts = [subtitle, description].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// „Biológia – Labor”
    var nextLine: String? {
        let subject = nextSubject.trimmingCharacters(in: .whitespaces)
        guard !subject.isEmpty else { return nil }
        let room = nextRoom.trimmingCharacters(in: .whitespaces)
        return room.isEmpty ? subject : "\(subject) – \(room)"
    }
}
