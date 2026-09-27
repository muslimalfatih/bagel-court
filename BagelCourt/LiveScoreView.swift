import SwiftUI

struct LiveScoreView: View {
    @ObservedObject var match: TennisMatch
    var onNewMatch: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.12, blue: 0.22).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .padding(.bottom, 20)

                scoreboardCard
                    .padding(.horizontal, 16)

                Spacer()

                if match.winner != nil {
                    matchOverPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 48)
                } else {
                    scoringButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, 48)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.format.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                if match.isInTiebreak {
                    Text("TIEBREAK")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            Button(action: { match.undo() }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.subheadline)
                .foregroundStyle((match.canUndo && match.winner == nil) ? .white.opacity(0.75) : .white.opacity(0.2))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity((match.canUndo && match.winner == nil) ? 0.1 : 0.03))
                .clipShape(Capsule())
            }
            .disabled(!match.canUndo || match.winner != nil)
        }
    }

    // MARK: - Scoreboard

    private var scoreboardCard: some View {
        let completedCount = match.winner != nil ? match.sets.count : max(0, match.sets.count - 1)

        return VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("PLAYER")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                ForEach(0..<completedCount, id: \.self) { i in
                    Text("S\(i + 1)").frame(width: 38)
                }

                if match.winner == nil {
                    Text("SET").frame(width: 46)
                    Text("PTS").frame(width: 56)
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.vertical, 10)
            .padding(.trailing, 8)

            Divider().background(Color.white.opacity(0.15))

            playerRow(player: 1, completedCount: completedCount)

            Divider().background(Color.white.opacity(0.08))

            playerRow(player: 2, completedCount: completedCount)
        }
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private func playerRow(player: Int, completedCount: Int) -> some View {
        let isP1 = player == 1
        let name = isP1 ? match.player1Name : match.player2Name
        let isServing = match.server == player && match.winner == nil
        let pts = isP1 ? match.gameScore.p1 : match.gameScore.p2
        let color: Color = isP1
            ? Color(red: 0.2, green: 0.6, blue: 1.0)
            : Color(red: 1.0, green: 0.35, blue: 0.35)

        HStack(spacing: 0) {
            // Name + serve indicator
            HStack(spacing: 8) {
                if isServing {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                } else {
                    Spacer().frame(width: 9)
                }
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            // Completed set scores
            ForEach(0..<completedCount, id: \.self) { i in
                let g = isP1 ? match.sets[i].player1Games : match.sets[i].player2Games
                let won = isP1
                    ? match.sets[i].player1Games > match.sets[i].player2Games
                    : match.sets[i].player2Games > match.sets[i].player1Games
                Text("\(g)")
                    .font(.system(size: 16, weight: won ? .bold : .regular))
                    .foregroundStyle(won ? color : .white.opacity(0.45))
                    .frame(width: 38)
            }

            // Current set games + points (match ongoing only)
            if match.winner == nil {
                let curGames = isP1
                    ? match.sets[match.currentSetIndex].player1Games
                    : match.sets[match.currentSetIndex].player2Games

                Text("\(curGames)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 46)

                Text(pts)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 16)
        .padding(.trailing, 8)
    }

    // MARK: - Scoring Buttons

    private var scoringButtons: some View {
        VStack(spacing: 12) {
            pointButton(player: 1)
            pointButton(player: 2)
        }
    }

    @ViewBuilder
    private func pointButton(player: Int) -> some View {
        let isP1 = player == 1
        let name = isP1 ? match.player1Name : match.player2Name
        let color: Color = isP1
            ? Color(red: 0.2, green: 0.55, blue: 1.0)
            : Color(red: 0.95, green: 0.3, blue: 0.3)

        Button(action: { match.scorePoint(for: player) }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Point — \(name)")
                    .font(.headline)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Match Over

    private var matchOverPanel: some View {
        VStack(spacing: 20) {
            if let w = match.winner {
                let winnerName = w == 1 ? match.player1Name : match.player2Name
                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                    Text(winnerName)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("wins the match!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.bottom, 4)
            }

            Button(action: onNewMatch) {
                Text("NEW MATCH")
                    .font(.headline.bold())
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.22))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
