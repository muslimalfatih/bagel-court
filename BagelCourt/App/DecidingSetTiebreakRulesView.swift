import SwiftUI

/// Settings › Rules › Deciding Set Tiebreak.
struct DecidingSetTiebreakRulesView: View {
    var body: some View {
        RulesPage(title: "Deciding Set Tiebreak") {
            Text("If the match reaches a final set, this replaces the full set with a 10-point tiebreak. First to 10 points, win by 2, takes the match.")
                .rulesBodyStyle()
            Text("Without this, a tied final set keeps going game by game until someone leads by 2 — which can take a while.")
                .rulesBodyStyle()
            Text("Turn this on to keep close matches from running too long.")
                .rulesBodyStyle()
        }
    }
}

#Preview {
    let _ = BCFonts.register()
    NavigationStack { DecidingSetTiebreakRulesView() }
        .preferredColorScheme(.dark)
}
