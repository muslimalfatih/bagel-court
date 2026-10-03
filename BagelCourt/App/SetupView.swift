import SwiftUI
import SwiftData

// MARK: - Format preset (UI-only concept; wraps MatchFormat)

enum FormatPreset: String, CaseIterable, Identifiable {
    case shortSet  = "Short Set"
    case bestOf1   = "Best of 1"
    case proSet    = "Pro Set"
    case custom    = "Custom"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .bestOf1:   return "Single Set"
        case .proSet:    return "8 Games"
        case .shortSet:  return "4 Games"
        case .custom:    return "Manual Rules"
        }
    }

    /// Shown under the format grid for the selected preset.
    var explanation: String {
        switch self {
        case .bestOf1:   return "Just one set decides the match. Fast and simple."
        case .proSet:    return "First to 8 games wins, instead of the usual 6. One set only."
        case .shortSet:  return "First to 4 games wins. Good for quick practice or warm-up matches."
        case .custom:    return "Set your own games-per-set and scoring rules."
        }
    }

    var baseFormat: MatchFormat {
        switch self {
        case .bestOf1:   return .bestOf1
        case .proSet:    return .proSet
        case .shortSet:  return .shortSet
        case .custom:    return .custom
        }
    }
}

// MARK: - SetupView

struct SetupView: View {
    /// Called when the match started from here ends (Done or Abandon); the owner closes Setup.
    var onFinish: () -> Void

    init(preset: FormatPreset = .shortSet, noAdScoring: Bool = false, decidingSetTiebreak: Bool = false,
         onFinish: @escaping () -> Void) {
        _preset = State(initialValue: preset)
        _noAdScoring = State(initialValue: noAdScoring)
        _decidingSetTiebreak = State(initialValue: decidingSetTiebreak)
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
    @State private var preset: FormatPreset
    @State private var customSets  = MatchFormat.custom.bestOf
    @State private var customGames = MatchFormat.custom.gamesPerSet
    @State private var noAdScoring: Bool
    @State private var decidingSetTiebreak: Bool
    @FocusState private var focusedField: LineupFields.Field?

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

    /// The deciding-set tiebreak only takes effect with more than one set; MatchFormat drops it otherwise.
    private var finalFormat: MatchFormat {
        let base = preset == .custom ? MatchFormat(bestOf: customSets, gamesPerSet: customGames) : preset.baseFormat
        return MatchFormat(bestOf: base.bestOf, gamesPerSet: base.gamesPerSet,
                           decidingSetTiebreak: decidingSetTiebreak, noAdScoring: noAdScoring)
    }

    private var summaryText: String {
        let srv = firstServer == .home ? homeLabel.uppercased() : awayLabel.uppercased()
        let noAd = noAdScoring ? " • No-Ad" : ""   // only when on, to keep the bar short
        return "\(matchType.rawValue) • \(finalFormat.name)\(noAd) • \(homeLabel.uppercased()) VS \(awayLabel.uppercased()) • \(srv) SERVES"
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
                                     away1: $awayPlayer1, away2: $awayPlayer2, focus: $focusedField)
                    }
                    FormStep(number: "03", label: "Initial Serve") { serveStep }
                    FormStep(number: "04", label: "Match Format") { formatStep }
                }
                // The keyboard is only for the names: tapping outside a field or scrolling closes it.
                // Buttons, toggles and fields keep their own taps.
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            }
            .scrollDismissesKeyboard(.immediately)
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
                    Button { preset = p } label: { FormatCard(title: p.rawValue, subtitle: p.subtitle, selected: preset == p) }
                }
            }

            Label(preset.explanation, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(Color.bcMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.bcCard, in: RoundedRectangle(cornerRadius: BCRadius.control))

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

    /// Sets and games cover the other shapes (best of 3 or 5, shorter or longer sets). The tiebreak
    /// isn't set here: it always comes at games-all, so it's shown, not asked for.
    private var customPanel: some View {
        let f = finalFormat, t = f.tiebreakThreshold
        return VStack(spacing: BCLayout.intraStepSpacing) {
            StepperRow(label: "Best of",
                       subtitle: "Standard is 3 · " + (f.bestOf == 1 ? "One set decides the match" : "Win \(f.setsToWin) sets to take the match"),
                       value: $customSets, range: 1...5, step: 2)
            Divider().background(Color.bcBorder)
            StepperRow(label: "Games Per Set", subtitle: "Standard is 6 · Tiebreak triggers at \(t)-\(t)",
                       value: $customGames, range: 1...20)
        }
        .padding(BCLayout.intraStepSpacing)
        .cardSurface()
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

// MARK: - Previews (the format step is 04; scroll down in the canvas)

#Preview("Short Set, rules off") { SetupView.preview() }
#Preview("Best of 1") { SetupView.preview(.bestOf1) }
#Preview("Pro Set") { SetupView.preview(.proSet) }
#Preview("Custom, rules off") { SetupView.preview(.custom) }
#Preview("Custom, rules on") { SetupView.preview(.custom, noAdScoring: true, decidingSetTiebreak: true) }

private extension SetupView {
    static func preview(_ preset: FormatPreset = .shortSet, noAdScoring: Bool = false,
                        decidingSetTiebreak: Bool = false) -> some View {
        BCFonts.register()
        return SetupView(preset: preset, noAdScoring: noAdScoring, decidingSetTiebreak: decidingSetTiebreak) {}
            .modelContainer(for: MatchRecord.self, inMemory: true)
    }
}

// MARK: - Segment style (local helper)

private extension View {
    func segmentStyle(selected: Bool) -> some View {
        self.font(.bcMono(12, .medium)).tracking(0.96)
            .textCase(.uppercase)
            .foregroundStyle(selected ? Color.bcText : Color.bcMuted)
    }
}
