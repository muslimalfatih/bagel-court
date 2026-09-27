import SwiftUI
import SwiftData

/// Match history list — the main screen of BagelCourt.
struct HistoryView: View {
    var onNewMatch: (Match) -> Void
    var onResumeMatch: (LiveMatchController) -> Void

    @Query(sort: \MatchRecord.startDate, order: .reverse) private var records: [MatchRecord]
    @State private var showingSetup = false
    @State private var resumeCandidate: MatchRecord? = nil
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
                .listStyle(.plain)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "tennisball").foregroundStyle(Color.bcAccent)
                    Text("BAGEL COURT").wordmarkStyle()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSetup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.bcAccent)
                }
            }
        }
        .sheet(isPresented: $showingSetup) {
            SetupView { match in
                onNewMatch(match)
            }
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

    // MARK: - Match row

    @ViewBuilder
    private func matchRow(_ record: MatchRecord) -> some View {
        Group {
            if record.isCompleted {
                NavigationLink(value: record) {
                    rowContent(record)
                }
            } else {
                Button {
                    resumeCandidate = record
                } label: {
                    rowContent(record)
                }
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ record: MatchRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.homeDisplayName.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.white)
                    Text("VS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.bcMuted)
                    Text(record.awayDisplayName.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.white)
                }

                HStack(spacing: 8) {
                    Text(record.formatLabel).cardLabelStyle()
                    Text("•").foregroundStyle(Color.bcBorder)
                    Text(record.startDate.formatted(date: .abbreviated, time: .omitted))
                        .cardLabelStyle()
                }
            }

            Spacer()

            if !record.isCompleted {
                Text("IN PROGRESS")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.bcAccent)
                    .clipShape(Capsule())
            } else if let m = record.decoded, let w = m.winner {
                let winName = w == .home ? m.homeDisplayName : m.awayDisplayName
                Text(winName.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.bcAccent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "tennisball")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(Color.bcAccent.opacity(0.3))
            VStack(spacing: 8) {
                Text("No matches yet").optionTitleStyle()
                Text("Tap + to start your first match").optionSubtitleStyle()
            }
            Spacer()
            Button {
                showingSetup = true
            } label: {
                Text("New Match").primaryButtonStyle()
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .background(Color.bcAccent)
                    .clipShape(RoundedRectangle(cornerRadius: BCRadius.button))
            }
            .padding(.horizontal, BCLayout.horizontalMargin)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Delete

    private func deleteRecords(at offsets: IndexSet) {
        for i in offsets { context.delete(records[i]) }
    }

    // MARK: - Resume check

    private func checkForIncompleteMatch() {
        guard resumeCandidate == nil else { return }
        resumeCandidate = records.first(where: { !$0.isCompleted })
    }
}
