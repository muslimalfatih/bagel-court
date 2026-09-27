import SwiftUI

/// The primary live-scoring screen.
/// Two half-screen tap targets award points; the persistent scoreboard
/// at the top always shows sets, games, current game score, and server.
/// Requires `LiveMatchController` to be created by the caller and passed in.
struct InMatchView: View {
    @State var controller: LiveMatchController
    var onEnd: () -> Void

    @State private var showAbandonAlert = false
    @State private var celebrate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()

            // The top bar and scoreboard stay put; only the area below changes when the match ends.
            VStack(spacing: 0) {
                topBar
                // The courtside board: the current game score, readable from across the net.
                DotMatrixBoard(text: controller.isOver
                               ? "FINAL"
                               : controller.gameScore.displayString(server: controller.currentServer))
                    .padding(.horizontal, BCLayout.horizontalMargin)
                    .padding(.bottom, 16)
                scoreboardCard
                    .padding(.horizontal, BCLayout.horizontalMargin)
                    .padding(.bottom, 12)
                if controller.isOver {
                    matchOverPanel
                        .transition((reduceMotion ? AnyTransition.opacity : .opacity.combined(with: .scale(scale: 0.96)))
                            .animation(.bcSmooth))
                } else {
                    scoringArea
                        .transition(.opacity)
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
                    .foregroundStyle(Color.bcMuted)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(controller.format.displayLabel.uppercased())
                    .stepLabelStyle()
                if controller.isInTiebreak {
                    Text(controller.isSuperTiebreak ? "Match tiebreak" : "Tiebreak")
                        .modifier(LabelModifier(color: .bcText, size: 10))
                }
            }

            Spacer()

            Button {
                withAnimation(reduceMotion ? nil : .bcQuick) { controller.undo() }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bcSecondary)
            .disabled(!controller.canUndo)
        }
        .padding(.horizontal, BCLayout.horizontalMargin)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Scoreboard

    private var scoreboardCard: some View {
        let sets = controller.allSets
        let completedCount = controller.isOver ? sets.count : max(0, sets.count - 1)

        return VStack(spacing: 0) {
            columnHeaders(completedCount: completedCount, sets: sets)
            Divider().background(Color.bcBorder)
            playerRow(.home, sets: sets, completedCount: completedCount)
            Divider().background(Color.bcBorder.opacity(0.5))
            playerRow(.away, sets: sets, completedCount: completedCount)
        }
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
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
                Text("PTS").cardLabelStyle().frame(width: 52)
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
                        .foregroundStyle(Color.bcText)
                } else {
                    Spacer().frame(width: 12)
                }
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bcText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)

            // Completed set scores
            ForEach(0..<completedCount, id: \.self) { i in
                let val = isHome ? sets[i].home : sets[i].away
                let won = isHome ? sets[i].homeWon : sets[i].awayWon
                Text(sets[i].isSuperTiebreak ? "[\(val)]" : "\(val)")
                    .font(.bcMono(15, won ? .bold : .regular))
                    .foregroundStyle(won ? Color.bcAccent : Color.bcMuted)
                    .contentTransition(.numericText(value: Double(val)))
                    .frame(width: 34)
            }

            // Current set games
            if !controller.isOver {
                let curSet = sets.last!
                let curGames = isHome ? curSet.home : curSet.away
                Text("\(curGames)")
                    .font(.bcMono(20, .bold))
                    .foregroundStyle(Color.bcText)
                    .contentTransition(.numericText(value: Double(curGames)))
                    .frame(width: 38)

                Text(ptsLabel)
                    .font(.bcMono(18, .bold))
                    .foregroundStyle(Color.bcText)
                    .contentTransition(.numericText())
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
        .padding(.horizontal, BCLayout.horizontalMargin)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func pointButton(for side: Side, height: CGFloat) -> some View {
        let isHome = side == .home
        let name   = isHome ? controller.homeDisplayName : controller.awayDisplayName
        let serving = controller.currentServer == side

        Button {
            // Numbers roll in 0.2 s; an interruptible spring, so fast tapping is never held up.
            withAnimation(reduceMotion ? nil : .bcQuick) { controller.scorePoint(for: side) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: BCRadius.card)
                    .fill(Color.bcCard)
                    .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))

                VStack(spacing: 8) {
                    if serving {
                        Image(systemName: "tennisball.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bcText)
                    }
                    Text(name)
                        .playerNameStyle()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Point")
                        .stepLabelStyle()
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Match over

    private var matchOverPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                if let w = controller.winner {
                    let winName = w == .home ? controller.homeDisplayName : controller.awayDisplayName
                    VStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(Color.bcAccent)
                            .symbolEffect(.bounce, value: celebrate)
                        Text(winName)
                            .font(.bcSerif(40))
                            .foregroundStyle(Color.bcAccent)   // the winner
                        Text("wins the match").stepLabelStyle()
                    }
                    .padding(.bottom, 8)
                }

                Button("Done", action: onEnd)
                    .buttonStyle(.bcPrimary)
                    .padding(.horizontal, BCLayout.horizontalMargin)
            }
            .padding(.bottom, 48)
        }
        // One trophy bounce, landing with the controller's success haptic.
        .onAppear { celebrate = !reduceMotion }
    }
}
