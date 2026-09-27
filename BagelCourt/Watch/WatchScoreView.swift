import SwiftUI

/// Live scoreboard mirrored from the iOS app.
/// Add this file to the watchOS target only.
struct WatchScoreView: View {
    @ObservedObject var receiver = WatchConnectivityReceiver.shared

    var body: some View {
        if let snap = receiver.snapshot {
            liveScore(snap)
        } else {
            idleView
        }
    }

    // MARK: - Live score

    @ViewBuilder
    private func liveScore(_ s: ScoreSnapshot) -> some View {
        let homeSets = s.allSets.filter(\.homeWon).count
        let awaySets = s.allSets.filter(\.awayWon).count
        let homeGame = s.gameScore.homeLabel(server: s.server)
        let awayGame = s.gameScore.awayLabel(server: s.server)
        let winnerName: String? = s.winner.map {
            $0 == .home ? s.homeDisplayName : s.awayDisplayName
        }

        VStack(spacing: 6) {
            // Player names + set scores
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    nameTag(s.homeDisplayName, serving: s.server == .home)
                    nameTag(s.awayDisplayName, serving: s.server == .away)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(homeSets)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("\(awaySets)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            Divider()

            // Current game score
            HStack(spacing: 8) {
                Text(homeGame)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.yellow)
                Text("–")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.secondary)
                Text(awayGame)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.yellow)
            }
            .frame(maxWidth: .infinity)

            if let name = winnerName {
                Text("🏆 \(name.uppercased())")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.yellow)
            }
        }
        .padding(8)
    }

    private func nameTag(_ name: String, serving: Bool) -> some View {
        HStack(spacing: 4) {
            if serving {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 5, height: 5)
            }
            Text(name.uppercased())
                .font(.system(size: 9, weight: serving ? .black : .regular))
                .foregroundStyle(serving ? Color.white : Color.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tennisball")
                .font(.system(size: 28))
                .foregroundStyle(.yellow.opacity(0.5))
            Text("Waiting for match")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
