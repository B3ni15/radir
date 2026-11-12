import ActivityKit
import RadirKit
import SwiftUI
import WidgetKit

/// Az óra élő kártyája a zárolt képernyőn és a Dynamic Islandben.
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
                    LessonIcon(state: s, size: 44).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Timer(state: s).font(.title2.weight(.bold)).frame(width: 84, alignment: .trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.index + s.title).font(.headline).lineLimit(1)
                        if let line = s.secondLine { Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Progress(state: s)
                        if let next = s.nextLine { Text(next).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    // a sziget lekerekített sarka ne vágja le a szöveg elejét
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: s.icon).foregroundStyle(s.tint)
            } compactTrailing: {
                Timer(state: s).frame(width: 46, alignment: .trailing).font(.caption.weight(.semibold)).foregroundStyle(s.tint)
            } minimal: {
                Image(systemName: s.icon).foregroundStyle(s.tint)
            }
            .keylineTint(s.tint)
        }
    }
}

private struct LockScreenView: View {
    let state: LiveCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LessonIcon(state: state, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.index + state.title).font(.headline).lineLimit(1)
                    if let line = state.secondLine {
                        Text(line).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Timer(state: state)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(state.tint)
                    // a visszaszámláló szöveg magától teljes szélességet kérne; fix szélesség kell (Apple ajánlás)
                    .frame(width: 92, alignment: .trailing)
            }
            Progress(state: state)
            if let next = state.nextLine {
                Label(next, systemImage: "arrow.forward.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

private struct LessonIcon: View {
    let state: LiveCardContent
    let size: CGFloat

    var body: some View {
        Image(systemName: state.icon)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(state.tint.gradient))
    }
}

private struct Timer: View {
    let state: LiveCardContent

    var body: some View {
        if state.date.upperBound > state.date.lowerBound {
            Text(timerInterval: state.date, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Image(systemName: "checkmark")
        }
    }
}

private struct Progress: View {
    let state: LiveCardContent

    var body: some View {
        if state.date.upperBound > state.date.lowerBound {
            ProgressView(timerInterval: state.date, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(state.tint)
        }
    }
}

extension LiveCardContent {
    var tint: Color {
        let c = ARGB(hex: color) ?? ARGB(0xFF2F_6FEB)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    /// Terem vagy a szünet/óra leírása.
    var secondLine: String? {
        [subtitle, description].first { !$0.isEmpty }
    }

    var nextLine: String? {
        guard !nextSubject.isEmpty else { return nil }
        return nextRoom.isEmpty ? String(localized: "Következő: \(nextSubject)") : String(localized: "Következő: \(nextSubject), \(nextRoom)")
    }
}
