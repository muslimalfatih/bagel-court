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
                ToolbarItem(placement: .topBarLeading) {
                    Text("Settings").titleStyle()
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bcAccent)
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .preferredColorScheme(.dark)
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
