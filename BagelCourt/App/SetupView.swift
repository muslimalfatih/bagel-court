import SwiftUI
import SwiftData

// MARK: - Format preset (UI-only concept; wraps MatchFormat)

enum FormatPreset: String, CaseIterable, Identifiable {
    case bestOf3   = "Best of 3"
    case bestOf1   = "Best of 1"
    case proSet    = "Pro Set"
    case shortSet  = "Short Set"
    case custom    = "Custom"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .bestOf3:   return "Standard Tour"
        case .bestOf1:   return "Single Set"
        case .proSet:    return "8 Games"
        case .shortSet:  return "4 Games"
        case .custom:    return "Manual Rules"
        }
    }

    var baseFormat: MatchFormat {
        switch self {
        case .bestOf3:   return .bestOf3
        case .bestOf1:   return .bestOf1
        case .proSet:    return .proSet
        case .shortSet:  return .shortSet
        case .custom:    return .custom
        }
    }

    /// The preset a saved format was made from, by sets, games and tiebreak; anything else is Custom.
    init(_ format: MatchFormat) {
        self = Self.allCases.first {
            let b = $0.baseFormat
            return (b.bestOf, b.gamesPerSet, b.tiebreakAt) == (format.bestOf, format.gamesPerSet, format.tiebreakAt)
        } ?? .custom
    }
}

// MARK: - SetupView

struct SetupView: View {
    /// Called when the match started from here ends (Done or Abandon); the owner closes Setup.
    var onFinish: () -> Void

    init(noAdScoring: Bool = false, onFinish: @escaping () -> Void) {
        _noAdScoring = State(initialValue: noAdScoring)
        self.onFinish = onFinish
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var segmentHighlight
    @State private var controller: LiveMatchController?

    // Step 1
    @State private var matchType: MatchType = .singles
    // Step 2
    @State private var homePlayer1 = ""
    @State private var homePlayer2 = ""
    @State private var awayPlayer1 = ""
    @State private var awayPlayer2 = ""
    // Step 3
    @State private var firstServer: Side = .home
    @State private var coinAngle: Double = 0
    @State private var isFlipping = false
    // Step 4
    @State private var preset: FormatPreset = .bestOf3
    @State private var customGames    = 4
    @State private var customTiebreak = 3
    @State private var noAdScoring: Bool
    @State private var decidingSetTiebreak = false

    private var isDoubles: Bool { matchType != .singles }

    private var h1: String { homePlayer1.trimmingCharacters(in: .whitespaces) }
    private var h2: String { homePlayer2.trimmingCharacters(in: .whitespaces) }
    private var a1: String { awayPlayer1.trimmingCharacters(in: .whitespaces) }
    private var a2: String { awayPlayer2.trimmingCharacters(in: .whitespaces) }

    private var canStart: Bool {
        guard !h1.isEmpty && !a1.isEmpty else { return false }
        return !isDoubles || (!h2.isEmpty && !a2.isEmpty)
    }

    private var homeLabel: String { LineupFields.teamName(h1, h2, isDoubles: isDoubles, fallback: "Home") }
    private var awayLabel: String { LineupFields.teamName(a1, a2, isDoubles: isDoubles, fallback: "Away") }

    private var finalFormat: MatchFormat {
        if preset == .custom {
            let fmt = MatchFormat(bestOf: 1, gamesPerSet: customGames,
                                  tiebreakAt: customTiebreak,
                                  decidingSetTiebreak: false,
                                  noAdScoring: noAdScoring)
            return fmt
        }
        var base = preset.baseFormat
        base.noAdScoring = noAdScoring
        guard decidingSetTiebreak && base.bestOf > 1 else { return base }
        return MatchFormat(bestOf: base.bestOf, gamesPerSet: base.gamesPerSet,
                           tiebreakAt: base.tiebreakAt, decidingSetTiebreak: true,
                           noAdScoring: noAdScoring)
    }

    private var summaryText: String {
        let srv = firstServer == .home ? homeLabel.uppercased() : awayLabel.uppercased()
        let noAd = noAdScoring ? " • No-Ad" : ""   // only when on, to keep the bar short
        return "\(matchType.rawValue) • \(preset.rawValue)\(noAd) • \(homeLabel.uppercased()) VS \(awayLabel.uppercased()) • \(srv) SERVES"
    }

    /// Says what is still missing while Start Match is disabled.
    private var missingNamesHint: String {
        isDoubles ? "Add all four player names to start" : "Add both player names to start"
    }

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    Divider().background(Color.bcBorder).padding(.bottom, BCLayout.stepSpacing)

                    FormStep(number: "01", label: "Match Type") { typeStep }
                    FormStep(number: "02", label: "Lineup") {
                        LineupFields(isDoubles: isDoubles, home1: $homePlayer1, home2: $homePlayer2,
                                     away1: $awayPlayer1, away2: $awayPlayer2)
                    }
                    FormStep(number: "03", label: "Initial Serve") { serveStep }
                    FormStep(number: "04", label: "Match Format") { formatStep }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { summaryBar }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $controller) { ctrl in
            InMatchView(controller: ctrl, onEnd: onFinish)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tennisball")
                    .foregroundStyle(Color.bcAccent)
                Text("BagelCourt").wordmarkStyle()
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.bcMuted)
            }
        }
        .padding(.horizontal, BCLayout.horizontalMargin)
        .padding(.vertical, 20)
    }

    // MARK: - Step 1: Match Type

    private var typeStep: some View {
        HStack(spacing: 0) {
            ForEach(MatchType.allCases, id: \.self) { type in
                Button {
                    withAnimation(reduceMotion ? .bcQuick : .bcSmooth) { matchType = type }
                } label: {
                    Text(type.rawValue)
                        .segmentStyle(selected: matchType == type)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background { if matchType == type { segmentFill } }
                }
            }
        }
        .padding(4)
        .overlay(Capsule().stroke(Color.bcBorder, lineWidth: 1))
    }

    /// The selected segment's pill slides between options; under Reduce Motion it just fades.
    @ViewBuilder
    private var segmentFill: some View {
        if reduceMotion {
            Capsule().fill(Color.bcCardActive)
        } else {
            Capsule().fill(Color.bcCardActive).matchedGeometryEffect(id: "segment", in: segmentHighlight)
        }
    }

    // MARK: - Step 3: Serve

    private var serveStep: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Who serves first?").stepLabelStyle()
                Spacer()
                coinTossButton
            }

            HStack(spacing: 12) {
                serveCard(for: .home, name: homeLabel)
                serveCard(for: .away, name: awayLabel)
            }
        }
    }

    private var coinTossButton: some View {
        Button(action: flipCoin) {
            HStack(spacing: 5) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(coinAngle))
                Text("Coin toss").cardLabelStyle(accent: true)
            }
            .foregroundStyle(Color.bcAccent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.bcAccent, lineWidth: 1))
        }
        .disabled(isFlipping)
    }

    private func flipCoin() {
        guard !isFlipping else { return }
        isFlipping = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let result: Side = Bool.random() ? .home : .away
        guard !reduceMotion else { return reveal(result) }
        withAnimation(.easeInOut(duration: 0.6)) { coinAngle += 720 } completion: { reveal(result) }
    }

    /// Shows the toss result the moment the coin stops, with the haptic on the same frame.
    private func reveal(_ side: Side) {
        withAnimation(.bcQuick) { firstServer = side }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isFlipping = false
    }

    @ViewBuilder
    private func serveCard(for side: Side, name: String) -> some View {
        let selected = firstServer == side
        Button { withAnimation(.bcQuick) { firstServer = side } } label: {
            VStack(spacing: 8) {
                Image(systemName: "person")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? Color.bcAccent : Color.bcMuted)
                Text(name.isEmpty ? (side == .home ? "Home" : "Away") : name)
                    .optionTitleStyle()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selected ? Color.bcCardActive : Color.bcCard)
            .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.card)
                    .stroke(selected ? Color.bcAccent : Color.bcBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
    }

    // MARK: - Step 4: Format

    private var formatStep: some View {
        VStack(spacing: 12) {
            let cols = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(FormatPreset.allCases) { p in
                    Button { preset = p } label: { FormatCard(preset: p, selected: preset == p) }
                }
            }

            if preset == .custom {
                customPanel
                    .transition(.bcReveal(reduceMotion: reduceMotion))
            }

            RuleToggle.noAdScoring(isOn: $noAdScoring)

            if finalFormat.bestOf > 1 {
                RuleToggle.decidingSetTiebreak(isOn: $decidingSetTiebreak)
                    .transition(.opacity)
            }
        }
        .animation(.bcSmooth, value: preset)
        .animation(.bcSmooth, value: finalFormat.bestOf)
    }

    private var customPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: BCLayout.intraStepSpacing) {
                StepperRow(label: "Games Per Set", subtitle: "Standard is 6",
                           value: $customGames, range: 1...20)
                Divider().background(Color.bcBorder)
                StepperRow(label: "Tiebreak At", subtitle: "\(customTiebreak)–\(customTiebreak)",
                           value: $customTiebreak, range: 1...customGames)
            }
            .padding(BCLayout.intraStepSpacing)
        }
        .cardSurface()
        .onChange(of: customGames) { _, new in
            customTiebreak = min(customTiebreak, new)
        }
    }

    // MARK: - Bottom summary bar

    private var summaryBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.bcBorder)

            VStack(spacing: 12) {
                // Wraps instead of scrolling sideways: with No-Ad on, even short names overflow one line.
                Text(canStart ? summaryText : missingNamesHint).summaryBarStyle(accent: false)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Start Match", action: startMatch)
                    .buttonStyle(.bcPrimary)
                    .disabled(!canStart)
                .animation(.bcQuick, value: canStart)
                .accessibilityHint(canStart ? "" : missingNamesHint)
            }
            .padding(.horizontal, BCLayout.horizontalMargin)
            .padding(.vertical, 16)
        }
        // Opaque, so the form never shows through the pinned bar.
        .background(Color.bcBg.ignoresSafeArea(edges: .bottom))
    }

    private func startMatch() {
        guard canStart else { return }
        let match = Match(
            type: matchType,
            homePlayer: h1,
            homePlayer2: isDoubles ? h2 : nil,
            awayPlayer: a1,
            awayPlayer2: isDoubles ? a2 : nil,
            format: finalFormat,
            initialServer: firstServer
        )
        // Presented over Setup: one motion up, instead of Setup closing and the match opening after it.
        controller = LiveMatchController(match: match, modelContext: context)
    }
}

// MARK: - Previews (the rule toggles are in step 04; scroll down in the canvas)

#Preview("No-ad scoring off") {
    let _ = BCFonts.register()
    SetupView {}
        .modelContainer(for: MatchRecord.self, inMemory: true)
}

#Preview("No-ad scoring on") {
    let _ = BCFonts.register()
    SetupView(noAdScoring: true) {}
        .modelContainer(for: MatchRecord.self, inMemory: true)
}

// MARK: - Segment style (local helper)

private extension View {
    func segmentStyle(selected: Bool) -> some View {
        self.font(.bcMono(12, .medium)).tracking(0.96)
            .textCase(.uppercase)
            .foregroundStyle(selected ? Color.bcText : Color.bcMuted)
    }
}
