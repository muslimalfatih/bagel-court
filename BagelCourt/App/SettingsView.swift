import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cbBg.ignoresSafeArea()

                List {
                    Section {
                        aboutRow(icon: "tennisball", title: "CourtBoard",
                                 subtitle: "Live tennis scoring for iPhone and Apple Watch")
                        aboutRow(icon: "number", title: "Version",
                                 subtitle: "\(appVersion) (\(buildNumber))")
                    } header: {
                        Text("About").stepLabelStyle().textCase(nil)
                    }
                    .listRowBackground(Color.cbCard)
                    .listRowSeparatorTint(Color.cbBorder)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SETTINGS").wordmarkStyle()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.cbAccent)
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
                .foregroundStyle(Color.cbAccent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).optionTitleStyle()
                Text(subtitle).optionSubtitleStyle()
            }
        }
        .padding(.vertical, 6)
    }
}
