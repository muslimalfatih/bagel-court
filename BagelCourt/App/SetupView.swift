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

    private var homeLabel: String {
        if h1.isEmpty { return "Home" }
        return isDoubles && !h2.isEmpty ? "\(h1) / \(h2)" : h1
    }
    private var awayLabel: String {
        if a1.isEmpty { return "Away" }
        return isDoubles && !a2.isEmpty ? "\(a1) / \(a2)" : a1
    }

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

                    stepBlock(number: "01", label: "Match Type") { typeStep }
                    stepBlock(number: "02", label: "Lineup")     { lineupStep }
                    stepBlock(number: "03", label: "Initial Serve") { serveStep }
                    stepBlock(number: "04", label: "Match Format") { formatStep }
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

    // MARK: - Step wrapper

    private func stepBlock<Content: View>(
        number: String, label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BCLayout.intraStepSpacing) {
            HStack(spacing: 8) {
                Text(number).stepLabelStyle()
                Text(label).stepLabelStyle()
            }
            content()
        }
        .padding(.horizontal, BCLayout.horizontalMargin)
        .padding(.bottom, BCLayout.stepSpacing)
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

    // MARK: - Step 2: Lineup

    private var lineupStep: some View {
        VStack(spacing: 12) {
            playerCard(side: .home)
            Text("vs").cardLabelStyle()
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.bcBorder, lineWidth: 1))
            playerCard(side: .away)
        }
    }

    @ViewBuilder
    private func playerCard(side: Side) -> some View {
        let isHome = side == .home

        VStack(alignment: .leading, spacing: 10) {
            Text(isHome ? "Home" : "Away").cardLabelStyle()

            nameField(placeholder: isHome ? "Player 1" : (isDoubles ? "Player 3" : "Player 2"),
                      text: isHome ? $homePlayer1 : $awayPlayer1)

            if isDoubles {
                nameField(placeholder: isHome ? "Player 2" : "Player 4",
                          text: isHome ? $homePlayer2 : $awayPlayer2)
                    .transition(.bcReveal(reduceMotion: reduceMotion))
            }
        }
        .padding(BCLayout.intraStepSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    private func nameField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Color.bcText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
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
                    formatCard(p)
                }
            }

            if preset == .custom {
                customPanel
                    .transition(.bcReveal(reduceMotion: reduceMotion))
            }

            ruleToggle("No-Ad Scoring", subtitle: "Sudden death at deuce — no advantage needed",
                       isOn: $noAdScoring)

            if finalFormat.bestOf > 1 {
                ruleToggle("Deciding set tiebreak", subtitle: "Super tiebreak instead of final set",
                           isOn: $decidingSetTiebreak)
                    .transition(.opacity)
            }
        }
        .animation(.bcSmooth, value: preset)
        .animation(.bcSmooth, value: finalFormat.bestOf)
    }

    /// A rule switch in the Match Format step. Both rule toggles use this row so they stay identical.
    private func ruleToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).optionTitleStyle()
                Text(subtitle).optionSubtitleStyle()
            }
        }
        .padding(BCLayout.intraStepSpacing)
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func formatCard(_ p: FormatPreset) -> some View {
        let selected = preset == p
        Button { preset = p } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.rawValue).optionTitleStyle()
                Text(p.subtitle).optionSubtitleStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BCLayout.intraStepSpacing)
            .background(selected ? Color.bcCardActive : Color.bcCard)
            .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.card)
                    .stroke(selected ? Color.bcAccent : Color.bcBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
    }

    private var customPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: BCLayout.intraStepSpacing) {
                stepperRow(
                    label: "Games Per Set",
                    subtitle: "Standard is 6",
                    value: $customGames,
                    range: 1...20
                )
                Divider().background(Color.bcBorder)
                stepperRow(
                    label: "Tiebreak At",
                    subtitle: "\(customTiebreak)–\(customTiebreak)",
                    value: $customTiebreak,
                    range: 1...customGames
                )
            }
            .padding(BCLayout.intraStepSpacing)
        }
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
        .onChange(of: customGames) { _, new in
            customTiebreak = min(customTiebreak, new)
        }
    }

    @ViewBuilder
    private func stepperRow(
        label: String, subtitle: String, value: Binding<Int>, range: ClosedRange<Int>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).optionTitleStyle()
                Text(subtitle).optionSubtitleStyle()
            }
            Spacer()
            HStack(spacing: 0) {
                // Decrement
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Text("–").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bcText)
                        .frame(width: 36, height: 36)
                        .background(Color.bcStepper)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.control))
                }

                Text("\(value.wrappedValue)")
                    .font(.bcMono(17, .medium))
                    .foregroundStyle(Color.bcText)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)

                // Increment
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Text("+").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bcOnAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.bcAccent)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.control))
                }
            }
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
