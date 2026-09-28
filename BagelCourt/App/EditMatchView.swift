import SwiftUI
import SwiftData

/// Corrects a match from History: player names, start date and, once it's finished, the final
/// score. The format is shown but can't change, because the points were played under it.
struct EditMatchView: View {
    let record: MatchRecord
    private let match: Match
    private let originalSets: [SetScore]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var home1: String
    @State private var home2: String
    @State private var away1: String
    @State private var away2: String
    @State private var startDate: Date
    @State private var sets: [SetScore]

    /// One set's score while editing. Sets are only added and removed at the end, so the set
    /// number is a stable id: removing a set never leaves a card bound to a missing index.
    private struct SetScore: Identifiable, Equatable {
        let id: Int
        var home: Int
        var away: Int
    }

    init(record: MatchRecord, match: Match) {
        self.record = record
        self.match = match
        let sets = match.isOver
            ? match.allSets.enumerated().map { SetScore(id: $0.offset + 1, home: $0.element.home, away: $0.element.away) }
            : []
        originalSets = sets
        _sets      = State(initialValue: sets)
        _home1     = State(initialValue: match.homePlayer)
        _home2     = State(initialValue: match.homePlayer2 ?? "")
        _away1     = State(initialValue: match.awayPlayer)
        _away2     = State(initialValue: match.awayPlayer2 ?? "")
        _startDate = State(initialValue: record.startDate)
    }

    private var format: MatchFormat { match.format }
    private var isDoubles: Bool { match.type != .singles }
    private var names: [String] {
        [home1, home2, away1, away2].map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var namesComplete: Bool {
        !names[0].isEmpty && !names[2].isEmpty && (!isDoubles || (!names[1].isEmpty && !names[3].isEmpty))
    }

    private var hasChanges: Bool {
        names != [match.homePlayer, match.homePlayer2 ?? "", match.awayPlayer, match.awayPlayer2 ?? ""]
            || startDate != record.startDate || sets != originalSets
    }

    /// The corrected match, or nil while the edited score can't finish a match.
    private var edited: Match? {
        let m = match.withDetails(homePlayer: names[0], homePlayer2: isDoubles ? names[1] : nil,
                                  awayPlayer: names[2], awayPlayer2: isDoubles ? names[3] : nil,
                                  startDate: startDate)
        guard sets != originalSets else { return m }   // untouched score: keep the real point log
        return m.withFinalScore(sets.map { SetResult(home: $0.home, away: $0.away) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bcBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        FormStep(number: "01", label: "Lineup") {
                            LineupFields(isDoubles: isDoubles, home1: $home1, home2: $home2,
                                         away1: $away1, away2: $away2)
                        }
                        FormStep(number: "02", label: "Date") { dateCard }
                        if match.isOver {
                            FormStep(number: "03", label: "Final Score") { scoreStep }
                        }
                        FormStep(number: match.isOver ? "04" : "03", label: "Match Format") { formatStep }
                    }
                    .padding(.top, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.bcMuted)
                        .font(.system(size: 14, weight: .semibold))
                }
                ToolbarItem(placement: .principal) {
                    Text("Edit Match").titleStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let canSave = hasChanges && namesComplete && edited != nil
                    Button("Save", action: save)
                        .foregroundStyle(canSave ? Color.bcAccent : Color.bcMuted)
                        .font(.system(size: 14, weight: .bold))
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(hasChanges)   // a stray swipe shouldn't throw edits away
    }

    // MARK: - 02 Date

    private var dateCard: some View {
        DatePicker(selection: $startDate, in: ...Date.now) {
            Text("Started").optionTitleStyle()
        }
        .padding(BCLayout.intraStepSpacing)
        .cardSurface()
    }

    // MARK: - 03 Final score

    private var scoreStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($sets) { $set in
                setCard($set)
                    .transition(.bcReveal(reduceMotion: reduceMotion))
            }

            HStack(spacing: 12) {
                if sets.count < format.bestOf {
                    Button("Add set") {
                        withAnimation(.bcSmooth) { sets.append(SetScore(id: sets.count + 1, home: 0, away: 0)) }
                    }
                }
                if sets.count > 1 {
                    Button("Remove set \(sets.count)") {
                        withAnimation(.bcSmooth) { _ = sets.popLast() }
                    }
                }
            }
            .buttonStyle(.bcSecondary)

            if edited == nil {
                Text("These scores don't end the match. Each set needs a winner, and the last set must decide it.")
                    .font(.footnote)
                    .foregroundStyle(Color.bcMuted)
                    .transition(.opacity)
            }
        }
        .animation(.bcQuick, value: edited == nil)
    }

    private func setCard(_ set: Binding<SetScore>) -> some View {
        // In a deciding-set-tiebreak format the last set is a 10-point tiebreak, scored in points.
        let isMatchTiebreak = format.decidingSetTiebreak && set.wrappedValue.id == format.bestOf
        let range = isMatchTiebreak ? 0...99 : 0...(format.tiebreakThreshold + 1)   // 7 at most in a set to 6
        let home = LineupFields.teamName(names[0], names[1], isDoubles: isDoubles, fallback: "Home")
        let away = LineupFields.teamName(names[2], names[3], isDoubles: isDoubles, fallback: "Away")

        return VStack(spacing: BCLayout.intraStepSpacing) {
            Text(isMatchTiebreak ? "Match tiebreak" : "Set \(set.wrappedValue.id)").cardLabelStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            StepperRow(label: home, value: set.home, range: range)
            Divider().background(Color.bcBorder)
            StepperRow(label: away, value: set.away, range: range)
        }
        .padding(BCLayout.intraStepSpacing)
        .cardSurface()
    }

    // MARK: - 04 Match format (read-only)

    private var formatStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatCard(preset: FormatPreset(format))
            RuleToggle.noAdScoring(isOn: .constant(format.noAdScoring))
            if format.bestOf > 1 {
                RuleToggle.decidingSetTiebreak(isOn: .constant(format.decidingSetTiebreak))
            }
            Text("The format can't change after a match is played.")
                .font(.footnote)
                .foregroundStyle(Color.bcMuted)
        }
        .disabled(true)
    }

    // MARK: - Save

    private func save() {
        guard let edited else { return }
        try? record.applyEdit(edited)
        try? context.save()
        dismiss()
    }
}
