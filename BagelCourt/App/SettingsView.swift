import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bcBg.ignoresSafeArea()

                List {
                    // What each match option means, before the app details.
                    Section {
                        rulesRow("Match Format", subtitle: "Short Set, Best of 1, Pro Set, Custom") {
                            MatchFormatRulesView()
                        }
                        rulesRow("No-Ad Scoring", subtitle: "Sudden death at deuce") {
                            NoAdScoringRulesView()
                        }
                        rulesRow("Deciding Set Tiebreak", subtitle: "Super tiebreak instead of final set") {
                            DecidingSetTiebreakRulesView()
                        }
                    } header: {
                        Text("Rules").stepLabelStyle().textCase(nil)
                    }
                    .listRowBackground(Color.bcCard)
                    .listRowSeparatorTint(Color.bcBorder)

                    Section {
                        aboutRow(icon: "tennisball", title: "BagelCourt",
                                 subtitle: "Live tennis scoring for iPhone and Apple Watch")
                        aboutRow(icon: "number", title: "Version",
                                 subtitle: "\(appVersion) (\(buildNumber))")
                    } header: {
                        Text("About").stepLabelStyle().textCase(nil)
                    }
                    .listRowBackground(Color.bcCard)
                    .listRowSeparatorTint(Color.bcBorder)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("")
            .toolbar {
                // No glass capsule behind the title on iOS 26; iOS 18 has none to hide.
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarLeading) { title }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { title }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bcAccent)
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var title: some View {
        Text("Settings").titleStyle()
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    /// A Rules row opening its explanation. Same shape as an About row, in text styles that follow
    /// the reader's text size: `.callout` semibold is the rows' 16 pt at the default size.
    private func rulesRow<Page: View>(_ title: String, subtitle: String,
                                      @ViewBuilder page: @escaping () -> Page) -> some View {
        NavigationLink {
            page()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.bcText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.bcMuted)
            }
            .padding(.vertical, 6)
        }
    }

    private func aboutRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bcMuted)   // not tappable, so not gold
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).optionTitleStyle()
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.bcMuted)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Rules pages

/// The layout the three rules pages share: serif title in the bar, scrolling text on the page.
struct RulesPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BCLayout.horizontalMargin)
                    .padding(.vertical, 24)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(title).titleStyle() }
        }
    }
}

extension View {
    /// Reading text on a rules page: body size, primary colour, about 1.5 line height.
    func rulesBodyStyle() -> some View {
        font(.body).foregroundStyle(Color.bcText).lineSpacing(4)
    }
}
