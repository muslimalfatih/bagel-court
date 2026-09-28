import SwiftUI

// Form pieces shared by Setup and Edit Match, so both forms look and behave the same.

/// A numbered form step: "02  LINEUP" above its content.
struct FormStep<Content: View>: View {
    let number: String
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BCLayout.intraStepSpacing) {
            HStack(spacing: 8) {
                Text(number).stepLabelStyle()
                Text(label).stepLabelStyle()
            }
            content
        }
        .padding(.horizontal, BCLayout.horizontalMargin)
        .padding(.bottom, BCLayout.stepSpacing)
    }
}

/// Home and away name cards, with a second name per side for doubles.
struct LineupFields: View {
    let isDoubles: Bool
    @Binding var home1: String
    @Binding var home2: String
    @Binding var away1: String
    @Binding var away2: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// "Dee / Vee" for a doubles pair, the one name in singles, `fallback` until a name is typed.
    static func teamName(_ first: String, _ second: String, isDoubles: Bool, fallback: String) -> String {
        if first.isEmpty { return fallback }
        return isDoubles && !second.isEmpty ? "\(first) / \(second)" : first
    }

    var body: some View {
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
                      text: isHome ? $home1 : $away1)

            if isDoubles {
                nameField(placeholder: isHome ? "Player 2" : "Player 4",
                          text: isHome ? $home2 : $away2)
                    .transition(.bcReveal(reduceMotion: reduceMotion))
            }
        }
        .padding(BCLayout.intraStepSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func nameField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Color.bcText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
    }
}

/// A number with – and + buttons, e.g. games per set.
struct StepperRow: View {
    let label: String
    var subtitle: String? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).optionTitleStyle()
                if let subtitle { Text(subtitle).optionSubtitleStyle() }
            }
            Spacer()
            HStack(spacing: 0) {
                Button(action: decrement) {
                    Text("–").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bcText)
                        .frame(width: 36, height: 36)
                        .background(Color.bcStepper)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.control))
                }
                .accessibilityLabel("Decrease \(label)")

                Text("\(value)")
                    .font(.bcMono(17, .medium))
                    .foregroundStyle(Color.bcText)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)

                Button(action: increment) {
                    Text("+").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bcOnAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.bcAccent)
                        .clipShape(RoundedRectangle(cornerRadius: BCRadius.control))
                }
                .accessibilityLabel("Increase \(label)")
            }
        }
    }

    private func decrement() { if value > range.lowerBound { value -= 1 } }
    private func increment() { if value < range.upperBound { value += 1 } }
}

/// A rule switch: title, a short capitalised summary and, optionally, a sentence explaining it.
struct RuleToggle: View {
    let title: String
    let subtitle: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).optionTitleStyle()
                Text(subtitle).optionSubtitleStyle()
                if let detail { Text(detail).optionDetailStyle().padding(.top, 2) }
            }
        }
        .padding(BCLayout.intraStepSpacing)
        .cardSurface()
    }

    static func noAdScoring(isOn: Binding<Bool>) -> RuleToggle {
        RuleToggle(title: "No-Ad Scoring", subtitle: "Sudden death at deuce — no advantage needed",
                   detail: "At 40-40, the next point wins the game outright. No back-and-forth.",
                   isOn: isOn)
    }

    static func decidingSetTiebreak(isOn: Binding<Bool>) -> RuleToggle {
        RuleToggle(title: "Deciding Set Tiebreak", subtitle: "Super tiebreak instead of final set",
                   detail: "If the match reaches a final set, play a 10-point tiebreak instead of a full set. Keeps close matches from running too long.",
                   isOn: isOn)
    }
}

/// A format preset's name and summary, as in Setup's format grid.
struct FormatCard: View {
    let preset: FormatPreset
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.rawValue).optionTitleStyle()
            Text(preset.subtitle).optionSubtitleStyle()
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
