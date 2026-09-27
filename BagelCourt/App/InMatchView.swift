import SwiftUI

/// The primary live-scoring screen.
/// Two half-screen tap targets award points; the persistent scoreboard
/// at the top always shows sets, games, current game score, and server.
/// Requires `LiveMatchController` to be created by the caller and passed in.
struct InMatchView: View {
    @State var controller: LiveMatchController
    var onEnd: () -> Void

    @State private var showAbandonAlert = false
    @State private var showGameBanner: Side? = nil  // flashes briefly after a game/set

    var body: some View {
        ZStack {
            Color.cbBg.ignoresSafeArea()

            if controller.isOver {
                matchOverView
            } else {
                VStack(spacing: 0) {
                    topBar
                    scoreboardCard
                        .padding(.horizontal, CBLayout.horizontalMargin)
                        .padding(.bottom, 12)
                    scoringArea
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear  { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert("Abandon Match?", isPresented: $showAbandonAlert) {
            Button("Abandon", role: .destructive) { onEnd() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("The match will be saved as incomplete.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { showAbandonAlert = true } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cbMuted)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(controller.format.displayLabel.uppercased())
                    .stepLabelStyle()
                if controller.isInTiebreak {
                    Text(controller.isSuperTiebreak ? "MATCH TIEBREAK" : "TIEBREAK")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.cbAccent)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { controller.undo() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(controller.canUndo ? Color.cbMuted : Color.cbBorder)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(controller.canUndo ? Color.cbCard : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CBRadius.button))
            }
            .disabled(!controller.canUndo)
        }
        .padding(.horizontal, CBLayout.horizontalMargin)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Scoreboard

    private var scoreboardCard: some View {
        let sets = controller.allSets
        let completedCount = controller.isOver ? sets.count : max(0, sets.count - 1)

        return VStack(spacing: 0) {
            columnHeaders(completedCount: completedCount, sets: sets)
            Divider().background(Color.cbBorder)
            playerRow(.home, sets: sets, completedCount: completedCount)
            Divider().background(Color.cbBorder.opacity(0.5))
            playerRow(.away, sets: sets, completedCount: completedCount)
        }
        .background(Color.cbCard)
        .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
        .overlay(RoundedRectangle(cornerRadius: CBRadius.card).stroke(Color.cbBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func columnHeaders(completedCount: Int, sets: [SetResult]) -> some View {
        HStack(spacing: 0) {
            Text("PLAYER").cardLabelStyle().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
            ForEach(0..<completedCount, id: \.self) { i in
                Text("S\(i+1)").cardLabelStyle().frame(width: 34)
            }
            if !controller.isOver {
                Text("G").cardLabelStyle().frame(width: 38)
                Text("PTS").cardLabelStyle(accent: true).frame(width: 52)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private func playerRow(_ side: Side, sets: [SetResult], completedCount: Int) -> some View {
        let isHome  = side == .home
        let name    = isHome ? controller.homeDisplayName : controller.awayDisplayName
        let serving = controller.currentServer == side
        let score   = controller.gameScore
        let ptsLabel = isHome ? score.homeLabel(server: controller.currentServer)
                               : score.awayLabel(server: controller.currentServer)

        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if serving {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.cbAccent)
                } else {
                    Spacer().frame(width: 12)
                }
                Text(name.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)

            // Completed set scores
            ForEach(0..<completedCount, id: \.self) { i in
                let val = isHome ? sets[i].home : sets[i].away
                let won = isHome ? sets[i].homeWon : sets[i].awayWon
                Text(sets[i].isSuperTiebreak ? "[\(val)]" : "\(val)")
                    .font(.system(size: 14, weight: won ? .black : .regular))
                    .foregroundStyle(won ? Color.cbAccent : Color.cbMuted)
                    .frame(width: 34)
            }

            // Current set games
            if !controller.isOver {
                let curSet = sets.last!
                let curGames = isHome ? curSet.home : curSet.away
                Text("\(curGames)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 38)

                Text(ptsLabel)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.cbAccent)
                    .frame(width: 52)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 8)
    }

    // MARK: - Scoring area

    private var scoringArea: some View {
        GeometryReader { geo in
            VStack(spacing: 2) {
                pointButton(for: .home, height: (geo.size.height - 2) / 2)
                pointButton(for: .away, height: (geo.size.height - 2) / 2)
            }
        }
        .padding(.horizontal, CBLayout.horizontalMargin)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func pointButton(for side: Side, height: CGFloat) -> some View {
        let isHome = side == .home
        let name   = isHome ? controller.homeDisplayName : controller.awayDisplayName
        let serving = controller.currentServer == side

        Button {
            controller.scorePoint(for: side)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: CBRadius.card)
                    .fill(Color.cbCard)
                    .overlay(RoundedRectangle(cornerRadius: CBRadius.card).stroke(Color.cbBorder, lineWidth: 1))

                VStack(spacing: 8) {
                    if serving {
                        Image(systemName: "tennisball.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cbAccent)
                    }
                    Text(name.uppercased())
                        .playerNameStyle()
                        .lineLimit(1)
                    Text("POINT")
                        .stepLabelStyle()
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Match over

    private var matchOverView: some View {
        VStack(spacing: 0) {
            topBar

            scoreboardCard
                .padding(.horizontal, CBLayout.horizontalMargin)

            Spacer()

            VStack(spacing: 12) {
                if let w = controller.winner {
                    let winName = w == .home ? controller.homeDisplayName : controller.awayDisplayName
                    VStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(Color.cbAccent)
                        Text(winName.uppercased()).playerNameStyle()
                        Text("wins the match").stepLabelStyle()
                    }
                    .padding(.bottom, 8)
                }

                Button(action: onEnd) {
                    Text("Done").primaryButtonStyle()
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(Color.cbAccent)
                        .clipShape(RoundedRectangle(cornerRadius: CBRadius.button))
                }
                .padding(.horizontal, CBLayout.horizontalMargin)
            }
            .padding(.bottom, 48)
        }
    }
}
