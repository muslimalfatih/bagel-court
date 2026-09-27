import SwiftUI

/// Scorecard shown at match end and from history.
struct ResultView: View {
    let record: MatchRecord
    @State private var shareImage: UIImage? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    private var match: Match? { record.decoded }

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()

            if let m = match {
                ScrollView {
                    VStack(spacing: 24) {
                        scorecard(m)
                            .padding(.horizontal, BCLayout.horizontalMargin)

                        metaRow(m)
                            .padding(.horizontal, BCLayout.horizontalMargin)

                        shareButton(m)
                            .padding(.horizontal, BCLayout.horizontalMargin)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
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
                Text("SCORECARD").wordmarkStyle()
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
                Text("PLAYER").cardLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<sets.count, id: \.self) { i in
                    Text("S\(i+1)").cardLabelStyle().frame(width: 40)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().background(Color.bcBorder)

            playerResultRow(m, side: .home, sets: sets)
            Divider().background(Color.bcBorder.opacity(0.4))
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
                        .font(.system(size: 10)).foregroundStyle(Color.bcAccent)
                }
                Text(name.uppercased())
                    .font(.system(size: 14, weight: isWinner ? .black : .regular))
                    .foregroundStyle(isWinner ? Color.white : Color.bcMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<sets.count, id: \.self) { i in
                let val = isHome ? sets[i].home : sets[i].away
                let won = isHome ? sets[i].homeWon : sets[i].awayWon
                Text(sets[i].isSuperTiebreak ? "[\(val)]" : "\(val)")
                    .font(.system(size: 16, weight: won ? .black : .regular))
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
            metaItem(label: "FORMAT", value: m.format.displayLabel.uppercased())
            metaItem(label: "STARTED", value: record.startDate.formatted(date: .abbreviated, time: .shortened))
            if let end = record.endDate {
                let dur = end.timeIntervalSince(m.startDate)
                metaItem(label: "DURATION", value: durationString(dur))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).cardLabelStyle()
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
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

    @ViewBuilder
    private func shareButton(_ m: Match) -> some View {
        if let img = shareImage {
            ShareLink(item: Image(uiImage: img), preview: SharePreview("BagelCourt Scorecard", image: Image(uiImage: img))) {
                Text("Share Scorecard").primaryButtonStyle()
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .background(Color.bcAccent)
                    .clipShape(RoundedRectangle(cornerRadius: BCRadius.button))
            }
        } else {
            Button {
                renderScorecard(m, scale: displayScale)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Scorecard").primaryButtonStyle()
                }
                .frame(maxWidth: .infinity).frame(height: 64)
                .background(Color.bcAccent)
                .clipShape(RoundedRectangle(cornerRadius: BCRadius.button))
            }
        }
    }

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
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tennisball")
                        .foregroundStyle(Color.bcAccent)
                    Text("BAGEL COURT").wordmarkStyle()
                }
                Spacer()
            }

            let sets = match.allSets
            ForEach([Side.home, Side.away], id: \.self) { side in
                let isHome = side == .home
                let name   = isHome ? match.homeDisplayName : match.awayDisplayName
                let won    = match.winner == side
                HStack {
                    Text(name.uppercased())
                        .font(.system(size: 14, weight: won ? .black : .regular))
                        .foregroundStyle(won ? Color.white : Color.bcMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(0..<sets.count, id: \.self) { i in
                        let v = isHome ? sets[i].home : sets[i].away
                        let w2 = isHome ? sets[i].homeWon : sets[i].awayWon
                        Text("\(v)")
                            .font(.system(size: 15, weight: w2 ? .black : .regular))
                            .foregroundStyle(w2 ? Color.bcAccent : Color.bcMuted)
                            .frame(width: 32)
                    }
                }
            }

            Text(match.format.displayLabel.uppercased())
                .cardLabelStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.bcBg)
        .frame(width: 360)
    }
}
