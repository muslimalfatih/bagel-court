import SwiftUI

struct MatchSetupView: View {
    @Binding var activeMatch: TennisMatch?
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var format: LegacyMatchFormat = .bestOf3
    @State private var firstServer = 1
    @Environment(\.dismiss) var dismiss

    private var canStart: Bool {
        !player1Name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !player2Name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.12, blue: 0.22).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        playersSection
                        formatSection
                        serverSection
                        startButton
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Match")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PLAYERS")
            playerField(placeholder: "Player 1 name", text: $player1Name, number: 1)
            playerField(placeholder: "Player 2 name", text: $player2Name, number: 2)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MATCH FORMAT")
            HStack(spacing: 12) {
                ForEach(LegacyMatchFormat.allCases, id: \.self) { fmt in
                    Button(action: { format = fmt }) {
                        Text(fmt.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(format == fmt ? Color(red: 0.04, green: 0.12, blue: 0.22) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(format == fmt ? Color.yellow : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("FIRST SERVER")
            HStack(spacing: 12) {
                serverButton(player: 1, name: player1Name.isEmpty ? "Player 1" : player1Name)
                serverButton(player: 2, name: player2Name.isEmpty ? "Player 2" : player2Name)
            }
        }
    }

    private var startButton: some View {
        Button(action: startMatch) {
            Text("START MATCH")
                .font(.headline.bold())
                .foregroundStyle(canStart ? Color(red: 0.04, green: 0.12, blue: 0.22) : .white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canStart ? Color.yellow : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canStart)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.45))
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func playerField(placeholder: String, text: Binding<String>, number: Int) -> some View {
        let color: Color = number == 1 ? Color(red: 0.2, green: 0.6, blue: 1.0) : Color(red: 1.0, green: 0.35, blue: 0.35)
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(Text("\(number)").font(.subheadline.bold()).foregroundStyle(.white))

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(.white)
                .tint(.yellow)
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private func serverButton(player: Int, name: String) -> some View {
        let selected = firstServer == player
        Button(action: { firstServer = player }) {
            HStack(spacing: 8) {
                Image(systemName: "tennisball.fill")
                    .foregroundStyle(selected ? .yellow : .white.opacity(0.25))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.yellow.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func startMatch() {
        let p1 = player1Name.trimmingCharacters(in: .whitespaces)
        let p2 = player2Name.trimmingCharacters(in: .whitespaces)
        guard !p1.isEmpty && !p2.isEmpty else { return }
        activeMatch = TennisMatch(player1: p1, player2: p2, format: format, firstServer: firstServer)
        dismiss()
    }
}
