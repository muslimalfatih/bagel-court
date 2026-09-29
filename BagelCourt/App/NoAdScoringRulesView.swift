import SwiftUI

/// Settings › Rules › No-Ad Scoring.
struct NoAdScoringRulesView: View {
    var body: some View {
        RulesPage(title: "No-Ad Scoring") {
            Text("At 40-40, the next point wins the game outright. No back-and-forth advantage — whoever wins that point takes the game.")
                .rulesBodyStyle()
            Text("Turn this on if you want faster games. It's common in recreational and club play where matches need to fit in a limited court time.")
                .rulesBodyStyle()
            Text("Turn it off for standard scoring, where a player needs to win by 2 clear points after deuce.")
                .rulesBodyStyle()
        }
    }
}

#Preview {
    let _ = BCFonts.register()
    NavigationStack { NoAdScoringRulesView() }
        .preferredColorScheme(.dark)
}
