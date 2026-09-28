import SwiftUI
import SwiftData

/// Match history list — the main screen of BagelCourt.
struct HistoryView: View {
    var transitions: Namespace.ID
    var onResumeMatch: (LiveMatchController) -> Void

    // Animated, so deleting a row (or the last one, into the empty state) slides rather than snaps.
    @Query(sort: \MatchRecord.startDate, order: .reverse, animation: .bcSmooth) private var records: [MatchRecord]
    @State private var showingSetup = false
    @State private var showingSettings = false
    @State private var setupSource = "plus"   // the button Setup grows out of
    @State private var resumeCandidate: MatchRecord? = nil
    @State private var checkedForResume = false
    @State private var recordToEdit: MatchRecord? = nil
    @State private var recordToDelete: MatchRecord? = nil
    @State private var showDeleteConfirmation = false
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
                            // A match is a permanent record: every delete asks first, so no full swipe.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // The app-wide gold tint would paint Delete like Edit, so it takes the system red back.
                                Button(role: .destructive) { confirmDelete(record) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                                Button { recordToEdit = record } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color.bcAccent)
                            }
                            .contextMenu {
                                Button("Edit Match", systemImage: "pencil") { recordToEdit = record }
                                Button("Delete Match", systemImage: "trash", role: .destructive) { confirmDelete(record) }
                                    .tint(.red)
                            }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("")
        // The glass capsules and the sheets growing out of their buttons are iOS 26 only. iOS 18
        // gets a standard toolbar and sheets that slide up.
        .toolbar {
            // The wordmark is a title, not a control: no glass capsule, which also squeezed it to one letter.
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarLeading) { wordmark }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { wordmark }
            }
            // Both trailing buttons live in this one toolbar: split across two views' toolbars,
            // their zoom sources got crossed and the gear opened Setup.
            if #available(iOS 26, *) {
                ToolbarItem(placement: .navigationBarTrailing) { settingsButton }
                    .matchedTransitionSource(id: "settings", in: transitions)
            } else {
                ToolbarItem(placement: .navigationBarTrailing) { settingsButton }
            }
            // Separate glass capsules, so each sheet morphs out of its own button, not a shared pill.
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
            }
            if #available(iOS 26, *) {
                ToolbarItem(placement: .navigationBarTrailing) { newMatchButton }
                    .matchedTransitionSource(id: "plus", in: transitions)
            } else {
                ToolbarItem(placement: .navigationBarTrailing) { newMatchButton }
            }
        }
        .sheet(isPresented: $showingSetup) {
            // Closing Setup also closes the match presented over it, so it slides away in one motion.
            if #available(iOS 26, *) {
                SetupView { showingSetup = false }
                    .navigationTransition(.zoom(sourceID: setupSource, in: transitions))
            } else {
                SetupView { showingSetup = false }
            }
        }
        .sheet(isPresented: $showingSettings) {
            if #available(iOS 26, *) {
                SettingsView()
                    .navigationTransition(.zoom(sourceID: "settings", in: transitions))
            } else {
                SettingsView()
            }
        }
        .sheet(item: $recordToEdit) { record in
            if let match = record.decoded {
                EditMatchView(record: record, match: match)
            } else {
                Text("Could not load match.").foregroundStyle(Color.bcMuted)
            }
        }
        // Shared by the swipe action and the context menu. It never reads the record, which is
        // gone by the time the dialog finishes animating away.
        .confirmationDialog("Delete this match?", isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete Match", role: .destructive, action: deleteConfirmed)
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        } message: {
            Text("This can't be undone.")
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

    // MARK: - Toolbar items

    private var wordmark: some View {
        HStack(spacing: 8) {
            Image(systemName: "tennisball").foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)
            Text("BagelCourt").wordmarkStyle()
                .accessibilityAddTraits(.isHeader)
        }
        .fixedSize()
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bcMuted)
        }
        .accessibilityLabel("Settings")
    }

    private var newMatchButton: some View {
        Button {
            openSetup(from: "plus")
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.bcAccent)
        }
        .accessibilityLabel("New match")
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
        let winner = record.isCompleted ? record.decoded?.winner : nil

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // One text, so long doubles names wrap together instead of each truncating on its own.
                let vs = Text(" vs ").font(.bcMono(11, .medium)).tracking(0.88).foregroundStyle(Color.bcMuted)
                Text("\(teamName(record.homeDisplayName, won: winner == .home))\(vs)\(teamName(record.awayDisplayName, won: winner == .away))")
                    .lineLimit(2)

                // Also one text: format and date wrap as a line, never column by column.
                Text("\(record.formatLabel) · \(record.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .cardLabelStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !record.isCompleted {
                // The web's LIVE pill: gold outline with a dot.
                HStack(spacing: 5) {
                    Circle().fill(Color.bcAccent).frame(width: 5, height: 5)
                    Text("In progress").cardLabelStyle(accent: true)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.bcAccent, lineWidth: 1))
                .fixedSize()
            }
        }
        .padding(.vertical, 6)
    }

    /// A player or pair in a row title. The winner is gold with a trophy, as on the scorecard,
    /// so the row doesn't repeat the winner's name in a column of its own.
    private func teamName(_ name: String, won: Bool) -> Text {
        let text = Text(name).font(.system(size: 16, weight: .semibold))
        guard won else { return text.foregroundStyle(Color.bcText) }
        let trophy = Text(Image(systemName: "trophy.fill")).font(.system(size: 12))
        return Text("\(trophy)\u{00A0}\(text)").foregroundStyle(Color.bcAccent)   // no-break: the trophy stays with the name
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

    private func confirmDelete(_ record: MatchRecord) {
        recordToDelete = record
        showDeleteConfirmation = true
    }

    /// Deletes by object, not list position, so a list refreshing underneath can't shift it onto
    /// another match. The success haptic waits for the save: it means the match is really gone.
    private func deleteConfirmed() {
        guard let record = recordToDelete else { return }
        recordToDelete = nil
        context.delete(record)
        do {
            try context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            context.rollback()   // the row comes back rather than vanishing unsaved
        }
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
