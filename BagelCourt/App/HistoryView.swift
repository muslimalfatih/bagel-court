import SwiftUI
import SwiftData

/// Match history list — the main screen of BagelCourt.
struct HistoryView: View {
    var transitions: Namespace.ID
    var onResumeMatch: (LiveMatchController) -> Void

    @Query(sort: \MatchRecord.startDate, order: .reverse) private var records: [MatchRecord]
    @State private var showingSetup = false
    @State private var showingSettings = false
    @State private var setupSource = "plus"   // the button Setup grows out of
    @State private var resumeCandidate: MatchRecord? = nil
    @State private var checkedForResume = false
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            Color.bcBg.ignoresSafeArea()

            if records.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(records) { record in
                        matchRow(record)
                            .listRowBackground(Color.bcCard)
                            .listRowSeparatorTint(Color.bcBorder)
                    }
                    .onDelete(perform: deleteRecords)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("")
        .toolbar {
            // The wordmark is a title, not a control: no glass capsule, which also squeezed it to one letter.
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    Image(systemName: "tennisball").foregroundStyle(Color.bcAccent)
                        .accessibilityHidden(true)
                    Text("BagelCourt").wordmarkStyle()
                        .accessibilityAddTraits(.isHeader)
                }
                .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            // Both trailing buttons live in this one toolbar: split across two views' toolbars,
            // their zoom sources got crossed and the gear opened Setup.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcMuted)
                }
                .accessibilityLabel("Settings")
            }
            .matchedTransitionSource(id: "settings", in: transitions)
            // Separate glass capsules, so each sheet morphs out of its own button, not a shared pill.
            ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    openSetup(from: "plus")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.bcAccent)
                }
                .accessibilityLabel("New match")
            }
            .matchedTransitionSource(id: "plus", in: transitions)
        }
        .sheet(isPresented: $showingSetup) {
            // Closing Setup also closes the match presented over it, so it slides away in one motion.
            SetupView { showingSetup = false }
                .navigationTransition(.zoom(sourceID: setupSource, in: transitions))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .navigationTransition(.zoom(sourceID: "settings", in: transitions))
        }
        .alert("Resume Match?", isPresented: .constant(resumeCandidate != nil)) {
            Button("Resume") {
                if let rec = resumeCandidate, let m = rec.decoded {
                    let ctrl = LiveMatchController(match: m, modelContext: context)
                    onResumeMatch(ctrl)
                }
                resumeCandidate = nil
            }
            Button("Discard", role: .destructive) {
                if let rec = resumeCandidate { context.delete(rec) }
                resumeCandidate = nil
            }
            Button("Cancel", role: .cancel) { resumeCandidate = nil }
        } message: {
            if let rec = resumeCandidate {
                Text("Continue \(rec.homeDisplayName) vs \(rec.awayDisplayName)?")
            }
        }
        .onAppear { checkForIncompleteMatch() }
    }

    private func openSetup(from source: String) {
        setupSource = source
        showingSetup = true
    }

    // MARK: - Match row

    @ViewBuilder
    private func matchRow(_ record: MatchRecord) -> some View {
        if record.isCompleted {
            NavigationLink(value: record) {
                rowContent(record)
            }
            .matchedTransitionSource(id: record.id, in: transitions)
        } else {
            Button {
                resumeCandidate = record
            } label: {
                rowContent(record)
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ record: MatchRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(record.homeDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcText)
                    Text("vs").cardLabelStyle()
                    Text(record.awayDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcText)
                }
                .lineLimit(1)

                HStack(spacing: 8) {
                    Text(record.formatLabel).cardLabelStyle()
                    Text("·").foregroundStyle(Color.bcMuted)
                    Text(record.startDate.formatted(date: .abbreviated, time: .omitted))
                        .cardLabelStyle()
                }
            }

            Spacer()

            if !record.isCompleted {
                // The web's LIVE pill: gold outline with a dot.
                HStack(spacing: 5) {
                    Circle().fill(Color.bcAccent).frame(width: 5, height: 5)
                    Text("In progress").cardLabelStyle(accent: true)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.bcAccent, lineWidth: 1))
            } else if let m = record.decoded, let w = m.winner {
                Text(w == .home ? m.homeDisplayName : m.awayDisplayName)
                    .cardLabelStyle(accent: true)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "tennisball")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.bcMuted)
            VStack(spacing: 8) {
                Text("No matches yet").titleStyle()
                Text("Tap + to start your first match")
                    .font(.subheadline)
                    .foregroundStyle(Color.bcMuted)
            }
            Spacer()
            Button("New Match") { openSetup(from: "newMatchButton") }
                .buttonStyle(.bcPrimary)
                .matchedTransitionSource(id: "newMatchButton", in: transitions)
                .padding(.horizontal, BCLayout.horizontalMargin)
                .padding(.bottom, 48)
        }
    }

    // MARK: - Delete

    private func deleteRecords(at offsets: IndexSet) {
        for i in offsets { context.delete(records[i]) }
    }

    // MARK: - Resume check

    /// Offers to resume an unfinished match once per launch. It used to ask again every time
    /// History reappeared, e.g. after closing each scorecard.
    private func checkForIncompleteMatch() {
        guard !checkedForResume else { return }
        checkedForResume = true
        resumeCandidate = records.first(where: { !$0.isCompleted })
    }
}
