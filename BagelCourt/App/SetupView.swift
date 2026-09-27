import SwiftUI

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
    var onStart: (Match) -> Void
    @Environment(\.dismiss) private var dismiss

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
        if h1.isEmpty { return "HOME" }
        return isDoubles && !h2.isEmpty ? "\(h1) / \(h2)" : h1
    }
    private var awayLabel: String {
        if a1.isEmpty { return "AWAY" }
        return isDoubles && !a2.isEmpty ? "\(a1) / \(a2)" : a1
    }

    private var finalFormat: MatchFormat {
        if preset == .custom {
            let fmt = MatchFormat(bestOf: 1, gamesPerSet: customGames,
                                  tiebreakAt: customTiebreak,
                                  decidingSetTiebreak: false)
            return fmt
        }
        let base = preset.baseFormat
        guard decidingSetTiebreak && base.bestOf > 1 else { return base }
        return MatchFormat(bestOf: base.bestOf, gamesPerSet: base.gamesPerSet,
                           tiebreakAt: base.tiebreakAt, decidingSetTiebreak: true)
    }

    private var summaryText: String {
        let srv = firstServer == .home ? homeLabel.uppercased() : awayLabel.uppercased()
        return "\(matchType.rawValue) • \(preset.rawValue) • \(homeLabel.uppercased()) VS \(awayLabel.uppercased()) • \(srv) SERVES"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bcBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    Divider().background(Color.bcBorder).padding(.bottom, BCLayout.stepSpacing)

                    stepBlock(number: "01", label: "Match Type") { typeStep }
                    stepBlock(number: "02", label: "Lineup")     { lineupStep }
                    stepBlock(number: "03", label: "Initial Serve") { serveStep }
                    stepBlock(number: "04", label: "Match Format") { formatStep }

                    Spacer().frame(height: 160)   // room for the pinned bar
                }
            }

            summaryBar
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tennisball")
                    .foregroundStyle(Color.bcAccent)
                Text("BAGEL COURT").wordmarkStyle()
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
                    matchType = type
                } label: {
                    Text(type.rawValue)
                        .segmentStyle(selected: matchType == type)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(matchType == type ? Color.bcAccent : Color.clear)
                }
            }
        }
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }

    // MARK: - Step 2: Lineup

    private var lineupStep: some View {
        VStack(spacing: 12) {
            playerCard(side: .home)
            Text("VS")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.bcMuted)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.bcCard)
                .clipShape(RoundedRectangle(cornerRadius: BCRadius.vsPill))
                .overlay(RoundedRectangle(cornerRadius: BCRadius.vsPill).stroke(Color.bcBorder, lineWidth: 1))
            playerCard(side: .away)
        }
    }

    @ViewBuilder
    private func playerCard(side: Side) -> some View {
        let isHome = side == .home
        let accentEdge = isHome

        VStack(alignment: .leading, spacing: 10) {
            Text(isHome ? "HOME" : "AWAY").cardLabelStyle(accent: isHome)

            nameField(placeholder: isHome ? "Player 1" : "Player 3",
                      text: isHome ? $homePlayer1 : $awayPlayer1)

            if isDoubles {
                nameField(placeholder: isHome ? "Player 2" : "Player 4",
                          text: isHome ? $homePlayer2 : $awayPlayer2)
            }
        }
        .padding(BCLayout.intraStepSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bcCard)
        .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        .overlay(alignment: .leading) {
            if accentEdge {
                RoundedRectangle(cornerRadius: BCRadius.card)
                    .fill(Color.bcAccent)
                    .frame(width: 4)
            }
        }
        .overlay {
            if !accentEdge {
                RoundedRectangle(cornerRadius: BCRadius.card)
                    .stroke(Color.bcBorder, lineWidth: 1)
            }
        }
    }

    private func nameField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 24, weight: .black))
            .textCase(.uppercase)
            .foregroundStyle(Color.white)
            .tint(Color.bcAccent)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
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
            HStack(spacing: 4) {
                Image(systemName: "circle.dashed")
                    .rotationEffect(.degrees(coinAngle))
                Text("Coin Toss").cardLabelStyle(accent: true)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.bcAccentDim)
            .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
        }
        .disabled(isFlipping)
    }

    private func flipCoin() {
        guard !isFlipping else { return }
        isFlipping = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.7)) { coinAngle += 720 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            firstServer = Bool.random() ? .home : .away
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            isFlipping = false
        }
    }

    @ViewBuilder
    private func serveCard(for side: Side, name: String) -> some View {
        let selected = firstServer == side
        Button { firstServer = side } label: {
            VStack(spacing: 8) {
                Image(systemName: "person")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? Color.bcAccent : Color.bcMuted)
                Text(name.isEmpty ? (side == .home ? "HOME" : "AWAY") : name)
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
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if finalFormat.bestOf > 1 {
                Toggle(isOn: $decidingSetTiebreak) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deciding set tiebreak").optionTitleStyle()
                        Text("Super tiebreak instead of final set").optionSubtitleStyle()
                    }
                }
                .tint(Color.bcAccent)
                .padding(BCLayout.intraStepSpacing)
                .background(Color.bcCard)
                .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: preset)
        .animation(.easeInOut(duration: 0.2), value: finalFormat.bestOf)
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
            Divider().background(Color.bcCustomBorder)
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
                Text(label).stepperLabelStyle()
                Text(subtitle).optionSubtitleStyle()
            }
            Spacer()
            HStack(spacing: 0) {
                // Decrement
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Text("–").font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.white)
                        .frame(width: 36, height: 36)
                        .background(Color.bcStepper)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.stepper))
                }

                Text("\(value.wrappedValue)")
                    .stepperLabelStyle()
                    .frame(width: 40)
                    .multilineTextAlignment(.center)

                // Increment
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Text("+").font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 36, height: 36)
                        .background(Color.bcAccent)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.stepper))
                }
            }
        }
    }

    // MARK: - Bottom summary bar

    private var summaryBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.bcBorder)

            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(summaryText).summaryBarStyle(accent: false)
                        .lineLimit(1)
                }

                Button(action: startMatch) {
                    Text("Start Match").primaryButtonStyle()
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(canStart ? Color.bcAccent : Color.bcBorder)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.button))
                }
                .disabled(!canStart)
            }
            .padding(.horizontal, BCLayout.horizontalMargin)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.95))
        }
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
        onStart(match)
        dismiss()
    }
}

// MARK: - Segment style (local helper)

private extension View {
    func segmentStyle(selected: Bool) -> some View {
        self.font(.system(size: 14, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(selected ? Color.black : Color.bcMuted)
    }
}
