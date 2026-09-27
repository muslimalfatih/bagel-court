import SwiftUI

/// Scorecard shown at match end and from history.
struct ResultView: View {
    let record: MatchRecord
    @State private var shareImage: UIImage? = nil
    @Environment(\.displayScale) private var displayScale

    private var match: Match? { record.decoded }

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()

            if let m = match {
                ScrollView {
                    VStack(spacing: 16) {
                        scorecard(m)
                        metaRow(m)
                    }
                    .padding(.horizontal, BCLayout.horizontalMargin)
                    .padding(.top, 24)
                    // Render up front so the first tap on Share opens the share sheet.
                    .onAppear { renderScorecard(m, scale: displayScale) }
                }
            } else {
                Text("Could not load match.")
                    .foregroundStyle(Color.bcMuted)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Scorecard").titleStyle()
            }
            // Share sits beside the title, as on the web, as the system's glass button.
            if let img = shareImage {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: Image(uiImage: img),
                              preview: SharePreview("BagelCourt Scorecard", image: Image(uiImage: img)))
                        .accessibilityLabel("Share scorecard")
                }
            }
        }
    }

    // MARK: - Scorecard card

    @ViewBuilder
    private func scorecard(_ m: Match) -> some View {
        let sets = m.allSets
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Player").cardLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<sets.count, id: \.self) { i in
                    Text("S\(i+1)").cardLabelStyle().frame(width: 40)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().background(Color.bcBorder)

            playerResultRow(m, side: .home, sets: sets)
            Divider().background(Color.bcBorder)
            playerResultRow(m, side: .away, sets: sets)
        }
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func playerResultRow(_ m: Match, side: Side, sets: [SetResult]) -> some View {
        let isHome  = side == .home
        let name    = isHome ? m.homeDisplayName : m.awayDisplayName
        let isWinner = m.winner == side

        HStack {
            HStack(spacing: 8) {
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11)).foregroundStyle(Color.bcAccent)
                }
                Text(name)
                    .font(.system(size: 16, weight: isWinner ? .semibold : .regular))
                    .foregroundStyle(isWinner ? Color.bcAccent : Color.bcText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<sets.count, id: \.self) { i in
                let val = isHome ? sets[i].home : sets[i].away
                let won = isHome ? sets[i].homeWon : sets[i].awayWon
                Text(sets[i].isSuperTiebreak ? "[\(val)]" : "\(val)")
                    .font(.bcMono(16, won ? .bold : .regular))
                    .foregroundStyle(won ? Color.bcAccent : Color.bcMuted)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
    }

    // MARK: - Meta info

    @ViewBuilder
    private func metaRow(_ m: Match) -> some View {
        HStack(spacing: 24) {
            metaItem(label: "Format", value: m.format.displayLabel)
            metaItem(label: "Started", value: record.startDate.formatted(date: .abbreviated, time: .shortened))
            if let end = record.endDate {
                let dur = end.timeIntervalSince(m.startDate)
                metaItem(label: "Duration", value: durationString(dur))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label).cardLabelStyle()
            Text(value)
                .font(.bcMono(12))
                .foregroundStyle(Color.bcText)
                .multilineTextAlignment(.center)
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - Share

    @MainActor
    private func renderScorecard(_ m: Match, scale: CGFloat) {
        let card = ScorecardRenderView(match: m)
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        shareImage = renderer.uiImage
    }
}

// MARK: - Standalone render view for ImageRenderer

/// Pure SwiftUI view rendered to an image for sharing.
/// Must be @MainActor safe (no UIKit dependencies).
private struct ScorecardRenderView: View {
    let match: Match
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tennisball")
                    .foregroundStyle(Color.bcAccent)
                Text("BagelCourt").wordmarkStyle()
            }

            let sets = match.allSets
            ForEach([Side.home, Side.away], id: \.self) { side in
                let isHome = side == .home
                let name   = isHome ? match.homeDisplayName : match.awayDisplayName
                let won    = match.winner == side
                HStack {
                    Text(name)
                        .font(.system(size: 15, weight: won ? .semibold : .regular))
                        .foregroundStyle(won ? Color.bcAccent : Color.bcText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(0..<sets.count, id: \.self) { i in
                        let v = isHome ? sets[i].home : sets[i].away
                        let w2 = isHome ? sets[i].homeWon : sets[i].awayWon
                        Text("\(v)")
                            .font(.bcMono(15, w2 ? .bold : .regular))
                            .foregroundStyle(w2 ? Color.bcAccent : Color.bcMuted)
                            .frame(width: 32)
                    }
                }
            }

            Text(match.format.displayLabel).cardLabelStyle()
        }
        .padding(24)
        .background(Color.bcBg)
        .frame(width: 360)
    }
}
