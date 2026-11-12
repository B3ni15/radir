import RadirKit
import SwiftUI

struct NewsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if app.server.visibleNews.isEmpty {
                    PanelGroup { PanelRow("Nincs hír", subtitle: "Ha a Radírral kapcsolatban újdonság lesz, itt olvashatod.", systemImage: "newspaper") }
                }
                ForEach(app.server.visibleNews) { NewsCard(item: $0) }
            }
            .padding(16)
        }
        .radirScreenBackground()
        .navigationTitle("Hírek")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.server.refresh() }
        .task { await app.server.refresh() }
    }
}

struct NewsCard: View {
    let item: RadirServer.NewsItem
    var onClose: (() -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if item.emergency {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(palette.warning)).accessibilityLabel("Fontos")
                }
                Text(item.title).font(.title(18, relativeTo: .headline))
                Spacer()
                if let onClose {
                    Button("Bezárás", systemImage: "xmark", action: onClose).labelStyle(.iconOnly)
                        .foregroundStyle(Color(palette.secondaryText))
                }
            }
            if !item.content.isEmpty {
                Text(HTMLText.plain(item.content)).font(.m(.subheadline)).foregroundStyle(Color(palette.secondaryText))
            }
            if let url = URL(string: item.link), !item.link.isEmpty {
                Link(item.openLabel.isEmpty ? String(localized: "Megnyitás") : item.openLabel, destination: url)
                    .font(.m(.subheadline, .semibold))
            }
        }
        .radirPanel()
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(palette.warning), lineWidth: item.emergency ? 1.5 : 0))
    }
}
