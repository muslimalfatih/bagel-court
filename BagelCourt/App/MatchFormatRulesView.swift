import SwiftUI

/// Settings › Rules › Match Format: one card per format, in the Setup grid's order.
struct MatchFormatRulesView: View {
    /// Names are stored in natural case; the heading style sets them in capitals.
    private let formats: [(name: String, explanation: String)] = [
        ("Short Set", "First to 4 games wins. Good for quick practice or warm-up matches."),
        ("Best of 1", "Just one set decides the match. Fast and simple."),
        ("Pro Set", "First to 8 games wins, instead of the usual 6. One set only."),
        ("Custom", "Set your own games-per-set and scoring rules. Starts from Best of 3 — win 2 out of 3 sets — as the default, which you can adjust to any format you like."),
    ]

    var body: some View {
        RulesPage(title: "Match Format") {
            ForEach(formats, id: \.name) { format in
                VStack(alignment: .leading, spacing: 8) {
                    Text(format.name)
                        .font(.bcMono(13, .bold)).tracking(13 * 0.08).textCase(.uppercase)
                        .foregroundStyle(Color.bcText)
                        .accessibilityAddTraits(.isHeader)
                    Text(format.explanation).rulesBodyStyle()
                }
                .padding(BCLayout.intraStepSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            }
        }
    }
}

#Preview {
    let _ = BCFonts.register()
    NavigationStack { MatchFormatRulesView() }
        .preferredColorScheme(.dark)
}
